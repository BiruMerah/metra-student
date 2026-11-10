#if os(iOS)
import AVFoundation
import ImageIO
import Vision

nonisolated enum DocumentCameraError: Error {
    case unavailable, captureFailed, incompletePage, notReady
}

nonisolated final class DocumentCameraSession: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    // All session changes, frame analysis and pending captures use this serial queue.
    private let queue = DispatchQueue(label: "metra.document-camera", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var guide = CameraPageGuide()
    private var lastAnalysisTime = -Double.infinity
    private var rotationAngle: CGFloat = 90
    private var onGuidance: (@MainActor @Sendable (CameraPageStatus) -> Void)?
    private var pendingCapture: PendingCapture?

    private struct PendingCapture {
        let id: Int64
        let continuation: CheckedContinuation<Data, Error>
        var data: Data?
    }

    func start(onGuidance: @escaping @MainActor @Sendable (CameraPageStatus) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.configure()
                    if !self.session.isRunning { self.session.startRunning() }
                    guard self.session.isRunning else { throw DocumentCameraError.unavailable }
                    self.onGuidance = onGuidance
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async {
            self.onGuidance = nil
            self.resetGuide()
            self.cancelPendingCapture()
            if self.isConfigured { self.session.stopRunning() }
        }
    }

    func interrupt() {
        queue.async {
            self.resetGuide()
            self.cancelPendingCapture()
        }
    }

    func setRotation(_ angle: CGFloat) {
        queue.async {
            guard self.rotationAngle != angle else { return }
            self.rotationAngle = angle
            self.resetGuide()
            self.publish(.searching)
        }
    }

    func capture() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.session.isRunning, !self.session.isInterrupted,
                      self.pendingCapture == nil,
                      let connection = self.photoOutput.connection(with: .video), connection.isActive,
                      self.guide.canCapture(at: ProcessInfo.processInfo.systemUptime) else {
                    self.resetGuide()
                    continuation.resume(throwing: DocumentCameraError.notReady)
                    return
                }
                if connection.isVideoRotationAngleSupported(self.rotationAngle) {
                    connection.videoRotationAngle = self.rotationAngle
                }
                let settings = AVCapturePhotoSettings()
                self.pendingCapture = PendingCapture(id: settings.uniqueID, continuation: continuation)
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func configure() throws {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw DocumentCameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
        guard session.canAddInput(input) else { throw DocumentCameraError.unavailable }
        session.addInput(input)
        guard session.canAddOutput(videoOutput) else {
            session.removeInput(input)
            throw DocumentCameraError.unavailable
        }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(videoOutput)
        guard session.canAddOutput(photoOutput) else {
            session.removeOutput(videoOutput)
            session.removeInput(input)
            throw DocumentCameraError.unavailable
        }
        session.addOutput(photoOutput)
        if let connection = videoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(0) {
            connection.videoRotationAngle = 0
        }
        isConfigured = true
    }

    private func resetGuide() {
        guide = CameraPageGuide()
        lastAnalysisTime = -.infinity
    }

    private func publish(_ status: CameraPageStatus) {
        guard let onGuidance else { return }
        Task { @MainActor in onGuidance(status) }
    }

    private func cancelPendingCapture() {
        let capture = pendingCapture
        pendingCapture = nil
        capture?.continuation.resume(throwing: CancellationError())
    }

    private var imageOrientation: CGImagePropertyOrientation {
        switch rotationAngle {
        case 0: .up
        case 180: .down
        case 270: .left
        default: .right
        }
    }

    private func detectPage(using handler: VNImageRequestHandler) -> CameraPageGeometry? {
        let request = VNDetectDocumentSegmentationRequest()
        guard (try? handler.perform([request])) != nil, let rectangle = request.results?.first else { return nil }
        return CameraPageGeometry(
            topLeft: rectangle.topLeft, topRight: rectangle.topRight,
            bottomRight: rectangle.bottomRight, bottomLeft: rectangle.bottomLeft
        )
    }

    private func photoContainsFullPage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_280
              ] as CFDictionary),
              let page = detectPage(using: VNImageRequestHandler(cgImage: image, orientation: .up)) else { return false }
        return page.hasFullPage && page.coverage >= 0.20
    }
}

extension DocumentCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard onGuidance != nil, pendingCapture == nil, now - lastAnalysisTime >= 0.20,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysisTime = now
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: imageOrientation)
        guide.update(page: detectPage(using: handler), at: now)
        publish(guide.status)
    }
}

extension DocumentCameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        let data = error == nil ? photo.fileDataRepresentation() : nil
        queue.async {
            guard self.pendingCapture?.id == id else { return }
            self.pendingCapture?.data = data
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor settings: AVCaptureResolvedPhotoSettings, error: Error?) {
        let id = settings.uniqueID
        let succeeded = error == nil
        queue.async {
            guard let capture = self.pendingCapture, capture.id == id else { return }
            self.pendingCapture = nil
            self.resetGuide()
            guard succeeded, let data = capture.data else {
                capture.continuation.resume(throwing: DocumentCameraError.captureFailed)
                return
            }
            guard self.photoContainsFullPage(data) else {
                capture.continuation.resume(throwing: DocumentCameraError.incompletePage)
                return
            }
            capture.continuation.resume(returning: data)
        }
    }
}
#endif
