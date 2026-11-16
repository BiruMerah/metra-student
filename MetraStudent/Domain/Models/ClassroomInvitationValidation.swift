import CloudKit
import Foundation

struct ClassroomInvitationValidationError: LocalizedError {
    enum Reason: String {
        case ownerAccount, containerMismatch, shareTypeMismatch, missingRootRecord
        case rootRecordType, rootZone, schemaVersion, classroomIdentity, classroomCode, ownerMismatch
    }

    let reason: Reason
    var receivedContainerIdentifier: String? = nil

    var errorDescription: String? {
        switch reason {
        case .ownerAccount:
            "Tautan ini dibuat oleh akun iCloud yang sedang digunakan. Untuk bergabung sebagai siswa, gunakan akun iCloud yang berbeda dari guru."
        case .containerMismatch:
            "Penyimpanan iCloud pada tautan berbeda dari aplikasi ini. Pastikan Metra Siswa sudah diperbarui dan menggunakan konfigurasi kelas yang sama dengan Metra Guru."
        case .missingRootRecord:
            "Data undangan kelas belum diterima dari iCloud. Coba lagi. Jika tetap gagal, kirim detail kesalahan kepada pengembang."
        case .ownerMismatch:
            "Pemilik undangan tidak cocok dengan pemilik kelas. Minta guru membuat ulang tautan undangan dari kelas tersebut."
        case .schemaVersion:
            "Format undangan belum didukung aplikasi ini. Perbarui Metra Guru dan Metra Siswa, lalu buat ulang tautan."
        case .shareTypeMismatch, .rootRecordType, .rootZone, .classroomIdentity, .classroomCode:
            "Data tautan tidak sesuai dengan undangan kelas Metra. Minta guru membuat ulang tautan dari kelas yang dipilih."
        }
    }

    /// Public configuration and validation stage only; no share tokens or user/record IDs.
    var diagnosticDetails: String {
        var details = "Validasi: \(reason.rawValue)\nApp: \(Bundle.main.bundleIdentifier ?? "tidak diketahui")\nContainer aplikasi: \(ClassroomInvitationContract.containerIdentifier ?? "default dari entitlements aplikasi")"
        if let receivedContainerIdentifier { details += "\nContainer tautan: \(receivedContainerIdentifier)" }
        return details
    }
}

/// Keeps the checks independent of CKShare.Metadata, which CloudKit alone creates.
enum ClassroomInvitationValidation {
    struct Payload: Equatable {
        let channelRecordName: String
        let code: String
        let zoneOwner: String
    }

    static func validateContainer(_ received: String, expected: String?) throws {
        guard received == expected else {
            throw ClassroomInvitationValidationError(reason: .containerMismatch, receivedContainerIdentifier: received)
        }
    }

    static func validateShareType(_ value: String?) throws {
        // CKShareTypeKey is an optional presentation/routing hint. The root's
        // schema, class owner, and active URL remain mandatory below.
        if let value, value != ClassroomInvitationContract.shareType {
            throw ClassroomInvitationValidationError(reason: .shareTypeMismatch)
        }
    }

    static func requireRecipient(isShareOwner: Bool, shareOwnerRecordName: String?, currentUserRecordName: String) throws {
        if isShareOwner || shareOwnerRecordName == currentUserRecordName {
            throw ClassroomInvitationValidationError(reason: .ownerAccount)
        }
    }

    static func payload(from root: CKRecord?) throws -> Payload {
        guard let root else { throw ClassroomInvitationValidationError(reason: .missingRootRecord) }
        guard root.recordType == ClassroomInvitationContract.recordType else {
            throw ClassroomInvitationValidationError(reason: .rootRecordType)
        }
        guard root.recordID.zoneID.zoneName == ClassroomInvitationContract.zoneName else {
            throw ClassroomInvitationValidationError(reason: .rootZone)
        }
        guard root["schemaVersion"] as? Int == ClassroomInvitationContract.schemaVersion else {
            throw ClassroomInvitationValidationError(reason: .schemaVersion)
        }
        guard let recordName = root["channelRecordName"] as? String, !recordName.isEmpty,
              root.recordID.recordName == ClassroomInvitationContract.recordName(for: recordName) else {
            throw ClassroomInvitationValidationError(reason: .classroomIdentity)
        }
        guard let code = root["channelCode"] as? String, !code.isEmpty else {
            throw ClassroomInvitationValidationError(reason: .classroomCode)
        }
        return Payload(channelRecordName: recordName, code: code, zoneOwner: root.recordID.zoneID.ownerName)
    }

    static func validateOwner(classCreator: String?, storedClassOwner: String?, shareOwner: String?,
                              zoneOwner: String, currentUser: String) throws {
        func resolved(_ name: String?) -> String? {
            guard let name, !name.isEmpty else { return nil }
            return name == CKCurrentUserDefaultName ? currentUser : name
        }
        // Prefer the immutable creator; a mutable owner field cannot override it.
        guard let classOwner = resolved(classCreator ?? storedClassOwner),
              let invitationOwner = resolved(shareOwner ?? zoneOwner),
              classOwner == invitationOwner else {
            throw ClassroomInvitationValidationError(reason: .ownerMismatch)
        }
    }
}
