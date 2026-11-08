#if os(iOS)
import Foundation
import UIKit
import WebKit

struct MathJaxParseResult: Sendable {
    let formulaID: String
    let mathML: String
    let parseMilliseconds: Double
    let hasMathErrorNode: Bool
    let parseError: String?
}

@MainActor
final class MathJaxBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private let webView: WKWebView
    private var ready = false
    private var unloaded = false
    private var loadingError: Error?
    private var readyWaiters: [CheckedContinuation<Void, Error>] = []
    private var pending: [String: CheckedContinuation<MathJaxParseResult, Error>] = [:]
    private var requestStarts: [String: Double] = [:]
    private var activeRequestID: String?

    var isUnusable: Bool { unloaded || loadingError != nil }

    override init() {
        let controller = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
        webView.isOpaque = false
        webView.alpha = 0
        webView.isUserInteractionEnabled = false
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        super.init()
        controller.add(self, name: "metra")
        webView.navigationDelegate = self
        attachToForegroundWindowIfAvailable()
        guard let html = Bundle.module.url(forResource: "MathJaxBridge", withExtension: "html"),
              let resourceRoot = Bundle.module.resourceURL else {
            loadingError = MathJaxBridgeError.bundleMissing
            return
        }
        webView.loadFileURL(html, allowingReadAccessTo: resourceRoot)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard let self, !self.ready, !self.unloaded else { return }
            self.failAll(MathJaxBridgeError.startupTimeout)
        }
    }

    private func attachToForegroundWindowIfAvailable() {
        guard webView.window == nil else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
            ?? scenes.first
        if let window = activeScene?.keyWindow ?? activeScene?.windows.first(where: { !$0.isHidden }) {
            window.addSubview(webView)
        }
    }

    func unload() {
        guard !unloaded else { return }
        unloaded = true
        failAll(MathJaxBridgeError.unloaded)
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "metra")
        webView.removeFromSuperview()
    }

    func convert(latex: String, formulaID: String) async throws -> MathJaxParseResult {
        attachToForegroundWindowIfAvailable()
        try await waitUntilReady()
        guard activeRequestID == nil else { throw MathJaxBridgeError.concurrentRequest }
        let requestID = UUID().uuidString
        activeRequestID = requestID
        let start = ProcessInfo.processInfo.systemUptime
        requestStarts[requestID] = start

        return try await withCheckedThrowingContinuation { continuation in
            pending[requestID] = continuation
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let self, let stalled = self.pending.removeValue(forKey: requestID) else { return }
                self.requestStarts.removeValue(forKey: requestID)
                self.activeRequestID = nil
                let timeoutError = MathJaxBridgeError.conversionTimeout
                self.loadingError = timeoutError
                stalled.resume(throwing: timeoutError)
            }
            guard let payload = Self.javascriptArray([requestID, formulaID, latex]) else {
                pending.removeValue(forKey: requestID)
                requestStarts.removeValue(forKey: requestID)
                activeRequestID = nil
                continuation.resume(throwing: MathJaxBridgeError.requestEncodingFailed)
                return
            }
            // metraConvert is async and returns a Promise. WKWebView cannot
            // transport that value through evaluateJavaScript. Return null;
            // only the request-ID script message completes a conversion.
            webView.evaluateJavaScript("window.metraConvert(\(payload)); null;") { _, error in
                // The JavaScript return value is not the conversion result.
                // A Promise/unsupported acknowledgement can arrive before the
                // request-ID postMessage; do not race it and discard valid MathML.
                // Real execution failures still fail, and absent messages time out.
                if let error, Self.isIgnorableAcknowledgementError(error) { return }
                if let error, let continuation = self.pending.removeValue(forKey: requestID) {
                    self.requestStarts.removeValue(forKey: requestID)
                    self.activeRequestID = nil
                    if Self.isRecoverableBridgeFailure(error) {
                        self.loadingError = error
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func isIgnorableAcknowledgementError(_ error: Error) -> Bool {
        let value = error as NSError
        return value.domain == WKErrorDomain && value.code == WKError.Code.javaScriptResultTypeIsUnsupported.rawValue
    }

    static func isRecoverableBridgeFailure(_ error: Error) -> Bool {
        if let bridgeError = error as? MathJaxBridgeError {
            switch bridgeError {
            case .startupTimeout, .conversionTimeout, .processTerminated, .unloaded:
                return true
            case .bundleMissing, .concurrentRequest, .requestEncodingFailed, .parseFailed:
                return false
            }
        }
        let nsError = error as NSError
        return nsError.domain == WKErrorDomain
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !unloaded, let body = message.body as? [String: Any] else { return }
        if body["kind"] as? String == "ready" {
            ready = true
            let waiters = readyWaiters
            readyWaiters.removeAll()
            waiters.forEach { $0.resume() }
            return
        }
        if body["kind"] as? String == "ready-error" {
            failAll(MathJaxBridgeError.parseFailed(body["error"] as? String ?? "startup failed"))
            return
        }
        guard let requestID = body["requestID"] as? String,
              let continuation = pending.removeValue(forKey: requestID) else { return }
        let started = requestStarts.removeValue(forKey: requestID) ?? ProcessInfo.processInfo.systemUptime
        activeRequestID = nil
        guard let mathML = body["mathml"] as? String else {
            let error = body["error"] as? String ?? "MathJax parse failed without a parser message."
            continuation.resume(throwing: MathJaxBridgeError.parseFailed(error))
            return
        }
        continuation.resume(returning: MathJaxParseResult(
            formulaID: body["formulaID"] as? String ?? "unknown",
            mathML: mathML,
            parseMilliseconds: (ProcessInfo.processInfo.systemUptime - started) * 1000,
            hasMathErrorNode: body["hasMathErrorNode"] as? Bool ?? false,
            parseError: body["error"] as? String
        ))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failAll(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failAll(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        failAll(MathJaxBridgeError.processTerminated)
    }

    private func waitUntilReady() async throws {
        if let loadingError { throw loadingError }
        if ready { return }
        try await withCheckedThrowingContinuation { continuation in
            readyWaiters.append(continuation)
        }
    }

    private func failAll(_ error: Error) {
        ready = false
        loadingError = error
        let waiters = readyWaiters
        readyWaiters.removeAll()
        waiters.forEach { $0.resume(throwing: error) }
        let activePending = Array(pending.values)
        pending.removeAll()
        requestStarts.removeAll()
        activeRequestID = nil
        activePending.forEach { $0.resume(throwing: error) }
    }

    private static func javascriptArray(_ values: [String]) -> String? {
        guard JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values, options: [.fragmentsAllowed]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum MathJaxBridgeError: LocalizedError {
    case bundleMissing
    case concurrentRequest
    case requestEncodingFailed
    case startupTimeout
    case conversionTimeout
    case processTerminated
    case unloaded
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundleMissing: "MathJaxBridge.html tidak ada di bundle aplikasi."
        case .concurrentRequest: "Bridge MathJax menerima satu ekspresi pada satu waktu."
        case .requestEncodingFailed: "Argumen formula tidak dapat dikodekan dengan aman untuk JavaScript."
        case .startupTimeout: "MathJax menolak LaTeX: startup timeout"
        case .conversionTimeout: "MathJax menolak LaTeX: conversion timeout"
        case .processTerminated: "Proses WebContent MathJax dihentikan sistem."
        case .unloaded: "Bridge MathJax sudah ditutup."
        case .parseFailed(let reason): "MathJax menolak LaTeX: \(reason)"
        }
    }
}

#endif
