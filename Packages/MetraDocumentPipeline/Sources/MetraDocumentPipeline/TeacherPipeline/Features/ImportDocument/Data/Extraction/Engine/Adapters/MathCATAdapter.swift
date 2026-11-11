#if os(iOS)
import Foundation
import MetraMathCAT

struct MathCATSpokenResult: Codable, Sendable {
    let spokenText: String
    let canonicalMathML: String?
    let profile: [String: String]
    let version: String
    let milliseconds: Double
    let speechStyle: String
    let fallbackTags: [String]
    let ssml: String?
}

enum MathCATError: LocalizedError {
    case failed(String)
    var errorDescription: String? { switch self { case .failed(let reason): return "MathCAT: \(reason)" } }
}

// Thread, rather than DispatchQueue/actor alone, guarantees MathCAT TLS affinity.
final class MathCATAdapter: @unchecked Sendable {
    static let shared = MathCATAdapter()
    private struct Job {
        let mathML: String
        let style: String
        let continuation: CheckedContinuation<MathCATSpokenResult, Error>
    }
    private let condition = NSCondition()
    private var jobs: [Job] = []
    private var worker: Thread!

    private init() {
        worker = Thread { [self] in workLoop() }
        worker.name = "org.metrapoc.mathcat-fixed-thread"
        worker.qualityOfService = .userInitiated
        worker.stackSize = 8 * 1024 * 1024
        worker.start()
    }

    func speak(mathML: String, style: String = "ClearSpeak") async throws -> MathCATSpokenResult {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            condition.lock()
            jobs.append(Job(mathML: mathML, style: style, continuation: continuation))
            condition.signal()
            condition.unlock()
        }
    }

    private func workLoop() {
        while true {
            condition.lock()
            while jobs.isEmpty { condition.wait() }
            let job = jobs.removeFirst()
            condition.unlock()
            autoreleasepool {
                do { job.continuation.resume(returning: try convert(job.mathML, style: job.style)) }
                catch { job.continuation.resume(throwing: error) }
            }
        }
    }

    private func convert(_ mathML: String, style: String) throws -> MathCATSpokenResult {
        guard Thread.current === worker else { throw MathCATError.failed("worker thread mismatch") }
        guard ["ClearSpeak", "SimpleSpeak", "LarrysSpeakeasy"].contains(style) else {
            throw MathCATError.failed("Gaya bacaan tidak didukung: \(style)")
        }
        let mathCATStyle = style == "LarrysSpeakeasy" ? "ClearSpeak" : style
        guard let rules = Bundle.module.resourceURL?.appendingPathComponent("MathCATRules"),
              FileManager.default.fileExists(atPath: rules.appendingPathComponent("Languages/id/\(mathCATStyle)_Rules.yaml").path) else {
            throw MathCATError.failed("Aturan id/\(mathCATStyle) tidak ada di bundle.")
        }
        let start = ProcessInfo.processInfo.systemUptime
        let pointer = rules.path.withCString { rulesPointer in
            mathML.withCString { mathPointer in
                style.withCString { metra_mathcat_convert_style(rulesPointer, mathPointer, $0) }
            }
        }
        guard let pointer else { throw MathCATError.failed("C ABI mengembalikan null") }
        defer { metra_mathcat_free(pointer) }
        let raw = String(cString: pointer)
        guard let data = raw.data(using: .utf8), let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              payload["ok"] as? Bool == true,
              let spoken = payload["spokenText"] as? String, !spoken.isEmpty,
              let profile = payload["profile"] as? [String: String], let version = payload["version"] as? String,
              payload["speechStyle"] as? String == style,
              profile["Language"] == "id", profile["SpeechStyle"] == mathCATStyle,
              let fallbackTags = payload["fallbackTags"] as? [String] else {
            throw MathCATError.failed(raw)
        }
        return MathCATSpokenResult(spokenText: spoken, canonicalMathML: payload["canonicalMathML"] as? String, profile: profile, version: version, milliseconds: (ProcessInfo.processInfo.systemUptime - start) * 1000,
            speechStyle: style, fallbackTags: fallbackTags, ssml: payload["ssml"] as? String)
    }
}

#endif
