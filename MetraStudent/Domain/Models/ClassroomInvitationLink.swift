import Foundation

/// Wire contract shared by the independently built Teacher and Student apps.
enum ClassroomInvitationContract {
    static var containerIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "MetraClassroomContainerIdentifier") as? String
    }
    static let zoneName = "MetraClassroomInvitations"
    static let recordType = "ClassroomInvitation"
    static let shareType = "id.birumerah.metra.student.classroom-invitation"
    static let schemaVersion = 1

    static func recordName(for channelRecordName: String) -> String {
        "INVITATION_\(channelRecordName)"
    }
}

struct ClassroomInvitationLink: Identifiable, Hashable, Sendable {
    let url: URL
    var id: String { url.absoluteString }

    init(url: URL) throws {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "https",
              ["icloud.com", "www.icloud.com"].contains(parts.host?.lowercased() ?? ""),
              parts.user == nil, parts.password == nil,
              parts.port == nil || parts.port == 443,
              parts.percentEncodedPath.range(of: #"^/share/[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else {
            throw ClassroomInvitationError.invalidLink
        }
        parts.scheme = "https"
        parts.host = "www.icloud.com"
        parts.port = nil
        parts.fragment = nil
        guard let normalized = parts.url else { throw ClassroomInvitationError.invalidLink }
        self.url = normalized
    }
}

enum ClassroomInvitationError: LocalizedError {
    case invalidLink, wrongContainer, unsupportedInvitation, unavailable, iCloudRequired, notOwner, linkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidLink: "Tautan undangan tidak valid. Gunakan tautan iCloud yang dibagikan guru."
        case .wrongContainer: "Penyimpanan iCloud pada tautan berbeda dari aplikasi ini. Pastikan Metra Siswa sudah diperbarui dan menggunakan konfigurasi kelas yang sama dengan Metra Guru."
        case .unsupportedInvitation: "Tautan ini bukan undangan kelas Metra. Minta guru membagikan tautan kelas yang benar."
        case .unavailable: "Undangan kelas sudah tidak tersedia. Minta guru membagikan undangan terbaru."
        case .iCloudRequired: "Masuk ke akun iCloud di Pengaturan untuk menggunakan undangan kelas."
        case .notOwner: "Hanya guru pemilik kelas yang dapat membuat tautan undangan."
        case .linkUnavailable: "iCloud belum mengembalikan tautan undangan. Coba buat tautan kembali."
        }
    }
}
