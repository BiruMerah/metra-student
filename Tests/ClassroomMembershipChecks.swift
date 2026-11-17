import CloudKit
import Foundation

@MainActor private final class MembershipDatabaseStub: ClassroomMembershipDatabase {
    let classroom = CKRecord(recordType: "ClassroomChannel", recordID: CKRecord.ID(recordName: "teacher-class"))
    var stored: StoredClassroomMembership?
    var saveCalls = 0
    var readCalls = 0
    var failuresRemaining = 0
    var saveError: Error?
    var afterSave: ((ClassroomMembership) -> Void)?

    init() {
        classroom["name"] = "Matematika"
        classroom["code"] = "AB12CD"
        classroom["members"] = ["Bu Guru"]
        classroom["ownerUserRecordID"] = "teacher-user"
        classroom["shareURL"] = "active-link"
    }

    func classroomRecord(for id: CKRecord.ID) async throws -> CKRecord {
        readCalls += 1
        guard id == classroom.recordID else { throw ClassroomInvitationError.unavailable }
        return classroom
    }

    func membership(for id: CKRecord.ID, currentUserRecordName: String) async throws -> StoredClassroomMembership? {
        stored
    }

    func saveMembership(_ membership: ClassroomMembership, existing: CKRecord?) async throws {
        saveCalls += 1
        if failuresRemaining > 0 { failuresRemaining -= 1; throw CKError(.serverRecordChanged) }
        if let saveError { throw saveError }
        guard membership.memberUserRecordID == "student-user" else { throw CKError(.permissionFailure) }
        let row = CKRecord(recordType: ClassroomMembership.recordType, recordID: membership.recordID)
        membership.applying(to: row)
        stored = StoredClassroomMembership(record: row, membership: membership)
        afterSave?(membership)
    }
}

@main private struct ClassroomMembershipChecks {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw NSError(domain: "MembershipChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        checks += 1
    }

    @MainActor static func register(_ database: MembershipDatabaseStub, name: String = "  Siswa Satu  ") async throws -> ClassroomMembershipRegistration.Result {
        try await ClassroomMembershipRegistration.register(classroomID: database.classroom.recordID,
            userRecordName: "student-user", displayName: name, database: database) { classroom in
                guard classroom["shareURL"] as? String == "active-link" else { throw ClassroomInvitationError.unavailable }
        }
    }

    @MainActor static func main() async throws {
        let first = ClassroomMembership(channelRecordName: "teacher-class", channelCode: "ab12cd",
            memberUserRecordID: "student-user", displayName: "  Siswa Satu  ", joinedAt: Date(timeIntervalSince1970: 1))
        try check(first.channelCode == "AB12CD" && first.displayName == "Siswa Satu", "Membership normalizes code and profile name")
        try check(first.recordID == ClassroomMembership.recordID(channelRecordName: "teacher-class", memberUserRecordID: "student-user"),
                  "Retry targets the same membership row")
        try check(first.recordID != ClassroomMembership.recordID(channelRecordName: "teacher-class", memberUserRecordID: "student-two"),
                  "Different iCloud users never write the same membership row")
        try check(first.recordID != ClassroomMembership.recordID(channelRecordName: "other-class", memberUserRecordID: "student-user"),
                  "Memberships in different classes remain independent")
        try check(ClassroomMembership.recordID(channelRecordName: "a", memberUserRecordID: "bc") !=
                  ClassroomMembership.recordID(channelRecordName: "ab", memberUserRecordID: "c"), "Identifier framing prevents concatenation collisions")
        try check(ClassroomMembership.authentic(recordID: first.recordID, channelRecordName: first.channelRecordName,
            memberUserRecordID: first.memberUserRecordID, creatorRecordName: "student-user", currentUserRecordName: "teacher-user"),
                  "Teacher trusts the immutable record creator for the student's identity")
        try check(ClassroomMembership.authentic(recordID: first.recordID, channelRecordName: first.channelRecordName,
            memberUserRecordID: first.memberUserRecordID, creatorRecordName: CKCurrentUserDefaultName, currentUserRecordName: "student-user"),
                  "A student's own default-owner alias resolves to their current account")
        try check(!ClassroomMembership.authentic(recordID: first.recordID, channelRecordName: first.channelRecordName,
            memberUserRecordID: first.memberUserRecordID, creatorRecordName: "attacker-user", currentUserRecordName: "teacher-user"),
                  "A row that claims another student's identity is rejected")
        try check(!ClassroomMembership.authentic(recordID: first.recordID, channelRecordName: first.channelRecordName,
            memberUserRecordID: first.memberUserRecordID, creatorRecordName: nil, currentUserRecordName: "student-user"),
                  "Missing authenticated creator identity is never trusted")
        try check(!ClassroomMembership.authentic(recordID: CKRecord.ID(recordName: "spoofed"), channelRecordName: first.channelRecordName,
            memberUserRecordID: first.memberUserRecordID, creatorRecordName: "student-user", currentUserRecordName: "teacher-user"),
                  "A mismatched membership record ID is rejected")
        let encoded = CKRecord(recordType: ClassroomMembership.recordType, recordID: first.recordID)
        first.applying(to: encoded)
        try check(encoded["displayName"] as? String == "Siswa Satu" && encoded["ownerUserRecordID"] == nil && encoded["members"] == nil,
                  "Membership payload contains no classroom owner/settings writes")
        try check(ClassroomMembership(record: encoded, currentUserRecordName: "student-user") == nil,
                  "Locally created payloads without server creator metadata cannot enter the trusted roster")

        let database = MembershipDatabaseStub()
        let joined = try await register(database)
        try check(database.saveCalls == 1 && joined.membership.recordID == first.recordID, "Joining creates one student-owned membership row")
        try check(database.classroom["members"] as? [String] == ["Bu Guru"] && database.classroom["name"] as? String == "Matematika"
                  && database.classroom["ownerUserRecordID"] as? String == "teacher-user", "Joining leaves every teacher-owned classroom field intact")
        let repeated = try await register(database)
        try check(database.saveCalls == 1 && repeated.membership.enrollmentKey == joined.membership.enrollmentKey,
                  "An already committed enrollment is idempotent without extra writes")
        let renamed = try await register(database, name: "Siswa Baru")
        try check(database.saveCalls == 2 && renamed.membership.displayName == "Siswa Baru"
                  && renamed.membership.enrollmentID == joined.membership.enrollmentID
                  && renamed.membership.joinedAt == joined.membership.joinedAt, "Changing the student's profile updates only their row and retains enrollment identity")
        let blank = MembershipDatabaseStub()
        do { _ = try await register(blank, name: "  "); throw NSError(domain: "BlankAccepted", code: 1) }
        catch ClassroomMembershipError.unreadable { try check(blank.saveCalls == 0, "Blank names never reach membership storage") }
        let denied = MembershipDatabaseStub()
        denied.saveError = CKError(.permissionFailure)
        do { _ = try await register(denied); throw NSError(domain: "DeniedJoinSucceeded", code: 1) }
        catch let error as CKError where error.code == .permissionFailure {
            try check(denied.stored == nil && denied.saveCalls == 1, "A failed membership commit cannot report success or be blindly retried")
        }
        let conflict = MembershipDatabaseStub()
        conflict.failuresRemaining = 2
        let recovered = try await register(conflict)
        try check(conflict.saveCalls == 3 && recovered.membership.recordID == first.recordID, "Conflict retries reuse the account's deterministic row")
        let exhausted = MembershipDatabaseStub()
        exhausted.failuresRemaining = 3
        do { _ = try await register(exhausted); throw NSError(domain: "UnboundedRetry", code: 1) }
        catch let error as CKError where error.code == .serverRecordChanged {
            try check(exhausted.saveCalls == 3 && exhausted.stored == nil, "Conflicts have a bounded retry budget")
        }
        let revoked = MembershipDatabaseStub()
        revoked.classroom["shareURL"] = "revoked-link"
        do { _ = try await register(revoked); throw NSError(domain: "RevokedAccepted", code: 1) }
        catch ClassroomInvitationError.unavailable { try check(revoked.saveCalls == 0, "Revocation is checked before a membership write") }
        let lateRevocation = MembershipDatabaseStub()
        lateRevocation.afterSave = { _ in lateRevocation.classroom["shareURL"] = "revoked-link" }
        do { _ = try await register(lateRevocation); throw NSError(domain: "LateRevokedAccepted", code: 1) }
        catch ClassroomInvitationError.unavailable { try check(lateRevocation.readCalls == 2, "The active invitation is rechecked after saving") }
        let removedDuringJoin = MembershipDatabaseStub()
        removedDuringJoin.afterSave = { membership in
            removedDuringJoin.classroom[ClassroomMembership.removedMembershipsKey] = [membership.enrollmentKey]
        }
        do { _ = try await register(removedDuringJoin); throw NSError(domain: "RemovedAccepted", code: 1) }
        catch ClassroomMembershipError.membershipChanged { checks += 1 }

        database.classroom[ClassroomMembership.removedMembershipsKey] = [renamed.membership.enrollmentKey]
        let rejoined = try await register(database, name: "Siswa Baru")
        try check(rejoined.membership.recordID == renamed.membership.recordID && rejoined.membership.enrollmentID != renamed.membership.enrollmentID,
                  "An explicit rejoin after removal uses a new enrollment in the same account-owned row")
        let stranger = ClassroomMembership(channelRecordName: "other-class", channelCode: "AB12CD", memberUserRecordID: "stranger", displayName: "Other")
        let second = ClassroomMembership(channelRecordName: "teacher-class", channelCode: "AB12CD", memberUserRecordID: "student-two", displayName: "Siswa Dua",
            enrollmentID: first.enrollmentID, joinedAt: Date(timeIntervalSince1970: 2))
        let active = ClassroomMembership.active(in: [second, stranger, first], channelRecordName: "teacher-class", channelCode: "ab12cd", removedMemberships: [])
        try check(active == [first, second], "Roster filters by immutable classroom ID and sorts enrollments consistently")
        let afterRemoval = ClassroomMembership.active(in: [first, second], channelRecordName: "teacher-class", channelCode: "AB12CD", removedMemberships: [first.enrollmentKey])
        try check(afterRemoval == [second], "A removal hides only the targeted membership even if two accounts choose the same enrollment UUID")
        try check(ClassroomMembership.roster(legacyMembers: ["Bu Guru", "Siswa Satu"], memberships: active) == ["Bu Guru", "Siswa Satu", "Siswa Dua"],
                  "The new roster preserves legacy members and avoids duplicate display names")

        let permission = StudentClassroomInvitationFailure(stage: .saveMembership, error: CKError(.permissionFailure), containerIdentifier: "iCloud.shared")
        try check(permission.code == 10 && permission.errorDescription?.contains("keanggotaan") == true
                  && permission.diagnosticDetails.contains("saveMembership"), "Membership permission errors identify their actual failing operation")
        let acceptance = StudentClassroomInvitationFailure(stage: .acceptShare, error: CKError(.permissionFailure), containerIdentifier: "iCloud.shared")
        try check(acceptance.errorDescription != permission.errorDescription && acceptance.diagnosticDetails.contains("acceptShare"),
                  "Accepting a share and writing membership have separate diagnostics")
        let partial = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: ["row": CKError(.permissionFailure), "rollback": CKError(.batchRequestFailed)]])
        let actual = StudentClassroomInvitationFailure(stage: .saveMembership, error: partial, containerIdentifier: "iCloud.shared")
        try check(actual.domain == CKErrorDomain && actual.code == 10, "An aggregate failure retains the permission cause rather than a rollback side effect")
        try check(!permission.diagnosticDetails.contains("student-user") && !permission.diagnosticDetails.contains("active-link"),
                  "Share tokens and account identities are excluded from copyable diagnostics")
        print("\(checks) membership ownership, registration, removal, retry, roster, and permission checks passed")
    }
}
