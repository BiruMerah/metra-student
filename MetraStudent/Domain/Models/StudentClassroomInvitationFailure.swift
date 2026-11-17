import CloudKit
import Foundation

struct StudentClassroomInvitationFailure: LocalizedError {
    enum Stage: String { case previewInvitation, acceptShare, saveMembership }
    let stage: Stage
    let containerIdentifier: String?
    let domain: String
    let code: Int

    init(stage: Stage, error: Error, containerIdentifier: String?) {
        self.stage = stage
        self.containerIdentifier = containerIdentifier
        let cause = Self.cause(of: error)
        self.domain = cause.domain
        self.code = cause.code
    }

    static func wrapping(_ error: Error, stage: Stage, containerIdentifier: String?) -> Error {
        if error is ClassroomInvitationError || error is ClassroomInvitationValidationError
            || error is CancellationError || error is Self { return error }
        return Self(stage: stage, error: error, containerIdentifier: containerIdentifier)
    }

    var errorDescription: String? {
        if domain == CKErrorDomain, code == CKError.Code.permissionFailure.rawValue {
            switch stage {
            case .saveMembership:
                return "iCloud menolak penyimpanan keanggotaan siswa. Pengelola perlu memeriksa izin record keanggotaan di CloudKit."
            case .acceptShare:
                return "iCloud menolak penerimaan undangan. Minta guru memeriksa akses undangan dan membagikan tautan terbaru."
            case .previewInvitation:
                return "iCloud menolak pembacaan undangan kelas. Minta guru memeriksa akses undangan."
            }
        }
        if stage == .saveMembership, domain == CKErrorDomain,
           [CKError.Code.unknownItem.rawValue, CKError.Code.invalidArguments.rawValue,
            CKError.Code.serverRejectedRequest.rawValue].contains(code) {
            return "Penyimpanan anggota kelas belum siap. Pengelola perlu memeriksa schema keanggotaan di CloudKit."
        }
        return "Undangan kelas belum bisa diproses. Periksa akun iCloud dan koneksi internet, lalu coba lagi."
    }

    var diagnosticDetails: String {
        "Tahap: \(stage.rawValue)\nError: \(domain) (\(code))\nApp: \(Bundle.main.bundleIdentifier ?? "tidak diketahui")\nContainer: \(containerIdentifier ?? "default dari entitlements aplikasi")"
    }

    private static func cause(of error: Error, depth: Int = 0) -> NSError {
        let error = error as NSError
        guard depth < 8 else { return error }
        if let partial = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            let causes = partial.values.map { cause(of: $0, depth: depth + 1) }
            return causes.first { $0.domain == CKErrorDomain && $0.code != CKError.Code.batchRequestFailed.rawValue }
                ?? causes.first ?? error
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
            return cause(of: underlying, depth: depth + 1)
        }
        return error
    }
}
