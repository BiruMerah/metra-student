#if os(iOS)
import AVFoundation
import Combine
import SwiftUI
import UIKit

struct DocumentCameraView: View {
    let onCapture: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @AccessibilityFocusState(for: .voiceOver) private var isCaptureFocused: Bool
    @State private var camera = DocumentCameraSession()
    @State private var phase: Phase = .starting

    private enum Phase: Equatable {
        case starting, scanning(CameraPageStatus), capturing, interrupted, failed(String), finished

        var message: String {
            switch self {
            case .starting: "Membuka kamera…"
            case .scanning(let status): status.message
            case .capturing: "Mengambil dan memeriksa foto…"
            case .interrupted: "Kamera dijeda. Tunggu sampai kamera tersedia kembali."
            case .failed(let message): message
            case .finished: ""
            }
        }

        var showsPreview: Bool {
            switch self {
            case .scanning, .capturing: true
            default: false
            }
        }

        var repeatsGuidance: Bool {
            if case .scanning(let status) = self { return status != .ready }
            return false
        }
    }

    private var isInBackground: Bool { scenePhase == .background }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            DocumentCameraPreview(camera: camera, showsPreview: phase.showsPreview)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: takePhoto)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(IndonesianSpeech.text("Area kamera"))
                .accessibilityValue(IndonesianSpeech.text(phase.message))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { takePhoto() }
                .accessibilityFocused($isCaptureFocused)

            IndonesianSpeech.text(phase.message)
                .font(AppTypography.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(AppSize.Spacing.large)
                .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: AppSize.Radius.cameraPanel))
                .padding(AppSize.Inset.page)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: AppSize.largeIconContainer, height: AppSize.largeIconContainer)
                    .background(.black.opacity(0.82), in: Circle())
            }
            .accessibilityLabel(IndonesianSpeech.text("Tutup kamera"))
            .padding(AppSize.Spacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityDefaultFocus($isCaptureFocused, true)
        .accessibilityAction(.escape, close)
        .task(id: isInBackground) {
            if isInBackground {
                phase = .interrupted
                camera.stop()
            } else {
                await start()
            }
        }
        .task(id: phase == .capturing) {
            guard phase == .capturing else { return }
            await capture()
        }
        .task(id: voiceOver && !isInBackground) {
            guard voiceOver, !isInBackground else { return }
            await speakGuidance()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.wasInterruptedNotification, object: camera.session)
            .receive(on: DispatchQueue.main)) { _ in
            guard phase.showsPreview else { return }
            phase = .interrupted
            camera.interrupt()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.interruptionEndedNotification, object: camera.session)
            .receive(on: DispatchQueue.main)) { _ in
            guard phase == .interrupted, !isInBackground else { return }
            phase = .scanning(.searching)
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.runtimeErrorNotification, object: camera.session)
            .receive(on: DispatchQueue.main)) { _ in
            guard phase.showsPreview || phase == .interrupted else { return }
            phase = .failed("Kamera berhenti. Tutup dan buka kembali kamera untuk mencoba lagi.")
            camera.stop()
        }
        .onDisappear(perform: stop)
    }

    private func start() async {
        phase = .starting
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed = if authorization == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .video)
        } else {
            authorization == .authorized
        }
        guard !Task.isCancelled, phase == .starting else { return }
        guard allowed else {
            phase = .failed("Akses kamera belum diizinkan. Izinkan akses kamera untuk Metra di Pengaturan.")
            return
        }

        do {
            try await camera.start { status in
                guard case .scanning(let previous) = phase, status != previous else { return }
                if status == .ready { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                phase = .scanning(status)
            }
            guard !Task.isCancelled, phase == .starting else { return }
            phase = .scanning(.searching)
            if voiceOver { isCaptureFocused = true }
        } catch {
            guard !Task.isCancelled, phase == .starting else { return }
            phase = .failed("Kamera belakang tidak tersedia. Tutup kamera untuk memilih foto dari galeri atau PDF.")
        }
    }

    private func takePhoto() {
        switch phase {
        case .scanning(.ready):
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            phase = .capturing
            announce("Mengambil foto.")
        case .scanning(let status):
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            announce("Halaman belum siap. \(status.message)")
        case .starting, .interrupted, .failed:
            announce(phase.message)
        case .capturing, .finished:
            break
        }
    }

    private func capture() async {
        do {
            let data = try await camera.capture()
            guard !Task.isCancelled, phase == .capturing else { return }
            onCapture(data)
            close()
        } catch {
            guard !Task.isCancelled, phase == .capturing else { return }
            phase = .scanning(.searching)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            switch error as? DocumentCameraError {
            case .incompletePage, .notReady:
                announce("Seluruh halaman belum terlihat. Arahkan kamera dan coba lagi.")
            default:
                announce("Foto belum berhasil diambil. Ikuti panduan kamera dan coba lagi.")
            }
        }
    }

    private func speakGuidance() async {
        var lastSpokenPhase: Phase?
        var lastAnnouncementTime = -Double.infinity
        do {
            while !Task.isCancelled, phase != .finished {
                let currentPhase = phase
                let time = ProcessInfo.processInfo.systemUptime
                let shouldRepeat = currentPhase.repeatsGuidance && time - lastAnnouncementTime >= 5
                if currentPhase != .starting, currentPhase != lastSpokenPhase || shouldRepeat {
                    announce(currentPhase.message)
                    lastSpokenPhase = currentPhase
                    lastAnnouncementTime = time
                }
                // Read the latest direction without queuing instructions from older frames.
                try await Task.sleep(for: .seconds(1.5))
            }
        } catch {
            // The camera closed, moved to the background, or VoiceOver was turned off.
        }
    }

    private func announce(_ message: String) {
        guard voiceOver, !Task.isCancelled, !isInBackground else { return }
        IndonesianSpeech.announce(message)
    }

    private func close() {
        stop()
        dismiss()
    }

    private func stop() {
        guard phase != .finished else { return }
        phase = .finished
        camera.stop()
    }
}

private struct DocumentCameraPreview: UIViewRepresentable {
    let camera: DocumentCameraSession
    let showsPreview: Bool

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.camera = camera
        let session = showsPreview ? camera.session : nil
        if view.previewLayer.session !== session { view.previewLayer.session = session }
        view.updateRotation()
    }

    final class PreviewView: UIView {
        var camera: DocumentCameraSession?

        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            updateRotation()
        }

        func updateRotation() {
            guard let orientation = window?.windowScene?.effectiveGeometry.interfaceOrientation else { return }
            let angle: CGFloat = switch orientation {
            case .landscapeRight: 0
            case .landscapeLeft: 180
            case .portraitUpsideDown: 270
            default: 90
            }
            if let connection = previewLayer.connection, connection.videoRotationAngle != angle,
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            camera?.setRotation(angle)
        }
    }
}
#endif
