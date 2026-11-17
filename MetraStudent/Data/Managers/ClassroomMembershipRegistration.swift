import CloudKit
import Foundation

enum ClassroomMembershipError: LocalizedError {
    case unreadable, membershipChanged

    var errorDescription: String? {
        switch self {
        case .unreadable: "Data keanggotaan belum bisa dibaca. Coba bergabung kembali."
        case .membershipChanged: "Keanggotaan berubah saat kamu bergabung. Coba bergabung kembali."
        }
    }
}

struct StoredClassroomMembership {
    let record: CKRecord
    let membership: ClassroomMembership
}

@MainActor
protocol ClassroomMembershipDatabase {
    func classroomRecord(for id: CKRecord.ID) async throws -> CKRecord
    func membership(for id: CKRecord.ID, currentUserRecordName: String) async throws -> StoredClassroomMembership?
    func saveMembership(_ membership: ClassroomMembership, existing: CKRecord?) async throws
}

@MainActor
struct CloudKitMembershipDatabase: ClassroomMembershipDatabase {
    let database: CKDatabase

    func classroomRecord(for id: CKRecord.ID) async throws -> CKRecord {
        do { return try await database.record(for: id) }
        catch let error as CKError where error.code == .unknownItem { throw ClassroomInvitationError.unavailable }
    }

    func membership(for id: CKRecord.ID, currentUserRecordName: String) async throws -> StoredClassroomMembership? {
        let record: CKRecord
        do { record = try await database.record(for: id) }
        catch let error as CKError where error.code == .unknownItem { return nil }
        guard let membership = ClassroomMembership(record: record, currentUserRecordName: currentUserRecordName) else {
            throw ClassroomMembershipError.unreadable
        }
        return StoredClassroomMembership(record: record, membership: membership)
    }

    func saveMembership(_ membership: ClassroomMembership, existing: CKRecord?) async throws {
        let record = existing ?? CKRecord(recordType: ClassroomMembership.recordType, recordID: membership.recordID)
        guard record.recordType == ClassroomMembership.recordType, record.recordID == membership.recordID else {
            throw ClassroomMembershipError.unreadable
        }
        membership.applying(to: record)
        _ = try await database.save(record)
    }
}

@MainActor
enum ClassroomMembershipRegistration {
    struct Result {
        let classroom: CKRecord
        let membership: ClassroomMembership
    }

    static func register(classroomID: CKRecord.ID, userRecordName: String, displayName: String,
                         database: any ClassroomMembershipDatabase,
                         validateClassroom: (CKRecord) throws -> Void) async throws -> Result {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ClassroomMembershipError.unreadable }
        let membershipID = ClassroomMembership.recordID(channelRecordName: classroomID.recordName, memberUserRecordID: userRecordName)
        for attempt in 0..<3 {
            try Task.checkCancellation()
            let classroom = try await database.classroomRecord(for: classroomID)
            try validateClassroom(classroom)
            guard classroom.recordType == "ClassroomChannel", classroom.recordID == classroomID,
                  let code = classroom["code"] as? String else { throw ClassroomInvitationError.unavailable }
            let stored = try await database.membership(for: membershipID, currentUserRecordName: userRecordName)
            if let previous = stored?.membership {
                guard previous.channelRecordName == classroomID.recordName,
                      previous.memberUserRecordID == userRecordName else { throw ClassroomMembershipError.unreadable }
            }
            let membership = ClassroomMembership.registration(existing: stored?.membership,
                channelRecordName: classroomID.recordName, channelCode: code,
                memberUserRecordID: userRecordName, displayName: name,
                removedMemberships: Set(classroom[ClassroomMembership.removedMembershipsKey] as? [String] ?? []))
            if membership != stored?.membership {
                do { try await database.saveMembership(membership, existing: stored?.record) }
                catch let error as CKError where error.code == .serverRecordChanged && attempt < 2 { continue }
            }
            // No ClassroomChannel write is exposed by the database interface.
            // Recheck revocation/removal before reporting local success.
            let latest = try await database.classroomRecord(for: classroomID)
            try validateClassroom(latest)
            guard latest["code"] as? String == code else { throw ClassroomInvitationError.unavailable }
            let removed = Set(latest[ClassroomMembership.removedMembershipsKey] as? [String] ?? [])
            guard !removed.contains(membership.enrollmentKey) else { throw ClassroomMembershipError.membershipChanged }
            return Result(classroom: latest, membership: membership)
        }
        throw CKError(.serverRecordChanged)
    }
}
