import AVFoundation
import UIKit

/// Explains why camera access is unavailable and whether app Settings can resolve it.
enum CameraPermissionFallback: Equatable {
    case denied
    case restricted

    var title: String {
        switch self {
        case .denied: "Akses Kamera Belum Diizinkan"
        case .restricted: "Akses Kamera Dibatasi"
        }
    }

    var message: String {
        switch self {
        case .denied:
            "Izinkan akses kamera untuk Metra di Pengaturan untuk mengambil foto halaman materi."
        case .restricted:
            "Akses kamera dibatasi di perangkat ini. Kamu tetap dapat memilih foto dari galeri atau berkas PDF."
        }
    }

    var canOpenSettings: Bool {
        self == .denied
    }
}

/// Checks and requests video capture authorization and opens app Settings when needed.
enum CameraPermission {
    static var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    static func fallback(for status: AVAuthorizationStatus) -> CameraPermissionFallback? {
        switch status {
        case .authorized, .notDetermined:
            nil
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .denied
        }
    }

    static func currentFallback() -> CameraPermissionFallback? {
        fallback(for: AVCaptureDevice.authorizationStatus(for: .video))
    }

    static func requestAccessIfNeeded() async -> CameraPermissionFallback? {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return nil
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { return nil }
            return currentFallback() ?? .denied
        case .denied, .restricted:
            return fallback(for: status)
        @unknown default:
            return .denied
        }
    }

    @MainActor
    static func openAppSettings(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            completion?(false)
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: completion)
    }
}
