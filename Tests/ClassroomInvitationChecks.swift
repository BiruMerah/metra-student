import Foundation
import CloudKit

@MainActor private final class InvitationReceiverStub: ClassroomInvitationReceiving {
    var previewCalls = 0
    var joinCalls = 0
    var failsPreview = false
    var cancelsPreview = false
    var failsJoin = false
    var receivedName: String?
    var previewError: Error?
    var duringJoin: (() async -> Void)?

    func previewInvitation(_ link: ClassroomInvitationLink) async throws -> ReceivedClassroomInvitation {
        previewCalls += 1
        if cancelsPreview { throw CancellationError() }
        if let previewError { throw previewError }
        if failsPreview { throw ClassroomInvitationError.unavailable }
        return .init(link: link, channelRecordName: "public-record", code: "AB12CD", name: "Matematika", teacherName: "Bu Guru")
    }

    func joinInvitation(_ invitation: ReceivedClassroomInvitation, displayMember: String) async throws -> ClassroomChannelModel {
        joinCalls += 1
        receivedName = displayMember
        await duringJoin?()
        if failsJoin { throw NSError(domain: "MembershipWriteFailed", code: 1) }
        return .init(code: invitation.code, name: invitation.name, createdBy: invitation.teacherName, members: [displayMember])
    }
}

@main private struct ClassroomInvitationChecks {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw NSError(domain: "StudentInvitationChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        checks += 1
    }

    static func expectValidation(_ reason: ClassroomInvitationValidationError.Reason, _ action: () throws -> Void) throws {
        do {
            try action()
            throw NSError(domain: "MissingValidationFailure", code: 1, userInfo: [NSLocalizedDescriptionKey: reason.rawValue])
        } catch let error as ClassroomInvitationValidationError {
            try check(error.reason == reason, "Expected \(reason.rawValue), got \(error.reason.rawValue)")
        }
    }

    static func rootRecord(type: String = ClassroomInvitationContract.recordType,
                           zone: String = ClassroomInvitationContract.zoneName,
                           recordName: String = "INVITATION_public-record") -> CKRecord {
        let zoneID = CKRecordZone.ID(zoneName: zone, ownerName: "teacher-user")
        let record = CKRecord(recordType: type, recordID: CKRecord.ID(recordName: recordName, zoneID: zoneID))
        record["schemaVersion"] = ClassroomInvitationContract.schemaVersion
        record["channelRecordName"] = "public-record"
        record["channelCode"] = "AB12CD"
        return record
    }

    @MainActor static func main() async throws {
        let url = URL(string: "https://www.icloud.com/share/ClassroomToken123")!
        let link = try ClassroomInvitationLink(url: url)
        let equivalent = try ClassroomInvitationLink(url: URL(string: "https://icloud.com:443/share/ClassroomToken123#Kelas")!)
        try check(link == equivalent, "A native metadata event and a decorated URL event identify the same invitation")
        for raw in ["http://www.icloud.com/share/token", "https://icloud.com.evil.test/share/token",
                    "https://user:password@www.icloud.com/share/token", "https://www.icloud.com/share/",
                    "https://www.icloud.com:444/share/token", "metra-student://join/AB12CD",
                    "file:///share/token", "https://www.icloud.com/share/a%2Fb"] {
            do { _ = try ClassroomInvitationLink(url: URL(string: raw)!); throw NSError(domain: "AcceptedInvalidLink", code: 1) }
            catch ClassroomInvitationError.invalidLink { checks += 1 }
        }

        try ClassroomInvitationValidation.validateContainer("iCloud.shared", expected: "iCloud.shared")
        try expectValidation(.containerMismatch) {
            try ClassroomInvitationValidation.validateContainer("iCloud.old", expected: "iCloud.shared")
        }
        try expectValidation(.containerMismatch) {
            try ClassroomInvitationValidation.validateContainer("iCloud.shared", expected: nil)
        }
        try ClassroomInvitationValidation.validateShareType(ClassroomInvitationContract.shareType)
        try ClassroomInvitationValidation.validateShareType(nil)
        try expectValidation(.shareTypeMismatch) { try ClassroomInvitationValidation.validateShareType("foreign.app.document") }
        try expectValidation(.ownerAccount) {
            try ClassroomInvitationValidation.requireRecipient(isShareOwner: true, shareOwnerRecordName: nil, currentUserRecordName: "teacher-user")
        }
        try expectValidation(.ownerAccount) {
            try ClassroomInvitationValidation.requireRecipient(isShareOwner: false, shareOwnerRecordName: "teacher-user", currentUserRecordName: "teacher-user")
        }
        try ClassroomInvitationValidation.requireRecipient(isShareOwner: false, shareOwnerRecordName: "teacher-user", currentUserRecordName: "student-user")
        try check(true, "A different iCloud account continues to payload and owner validation")
        let payload = try ClassroomInvitationValidation.payload(from: rootRecord())
        try check(payload.channelRecordName == "public-record" && payload.code == "AB12CD" && payload.zoneOwner == "teacher-user",
                  "A valid root resolves the exact public class and owner zone")
        try expectValidation(.missingRootRecord) { _ = try ClassroomInvitationValidation.payload(from: nil) }
        try expectValidation(.rootRecordType) { _ = try ClassroomInvitationValidation.payload(from: rootRecord(type: "OtherDocument")) }
        try expectValidation(.rootZone) { _ = try ClassroomInvitationValidation.payload(from: rootRecord(zone: "OtherZone")) }
        try expectValidation(.classroomIdentity) { _ = try ClassroomInvitationValidation.payload(from: rootRecord(recordName: "INVITATION_another-class")) }
        let malformedRoot = rootRecord()
        malformedRoot["schemaVersion"] = 2
        try expectValidation(.schemaVersion) { _ = try ClassroomInvitationValidation.payload(from: malformedRoot) }
        malformedRoot["schemaVersion"] = 1
        malformedRoot["channelRecordName"] = nil
        try expectValidation(.classroomIdentity) { _ = try ClassroomInvitationValidation.payload(from: malformedRoot) }
        malformedRoot["channelRecordName"] = "public-record"
        malformedRoot["channelCode"] = ""
        try expectValidation(.classroomCode) { _ = try ClassroomInvitationValidation.payload(from: malformedRoot) }
        try ClassroomInvitationValidation.validateOwner(classCreator: "teacher-user", storedClassOwner: "legacy-owner",
            shareOwner: "teacher-user", zoneOwner: "teacher-user", currentUser: "student-user")
        try check(true, "A verified teacher owner is accepted independently of an obsolete mutable owner field")
        try ClassroomInvitationValidation.validateOwner(classCreator: CKCurrentUserDefaultName, storedClassOwner: nil,
            shareOwner: "teacher-user", zoneOwner: CKCurrentUserDefaultName, currentUser: "teacher-user")
        try ClassroomInvitationValidation.validateOwner(classCreator: "teacher-user", storedClassOwner: nil,
            shareOwner: CKCurrentUserDefaultName, zoneOwner: CKCurrentUserDefaultName, currentUser: "teacher-user")
        try check(true, "CloudKit's current-user alias is resolved consistently on either side of ownership validation")
        try ClassroomInvitationValidation.validateOwner(classCreator: nil, storedClassOwner: "teacher-user",
            shareOwner: nil, zoneOwner: "teacher-user", currentUser: "student-user")
        try check(true, "Legacy class ownership and the authenticated share's owner zone can be used when identities are absent")
        try expectValidation(.ownerMismatch) {
            try ClassroomInvitationValidation.validateOwner(classCreator: "teacher-user", storedClassOwner: "attacker-user",
                shareOwner: "attacker-user", zoneOwner: "attacker-user", currentUser: "student-user")
        }
        try expectValidation(.ownerMismatch) {
            try ClassroomInvitationValidation.validateOwner(classCreator: nil, storedClassOwner: nil,
                shareOwner: "teacher-user", zoneOwner: "teacher-user", currentUser: "student-user")
        }

        let suite = "metra-invitation-checks-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let inbox = ClassroomInvitationInbox(defaults: defaults)
        inbox.receive(url)
        inbox.receive(equivalent.url)
        try check(inbox.links == [link], "Duplicate launch callbacks do not queue duplicate invitations")
        let restored = ClassroomInvitationInbox(defaults: defaults)
        try check(restored.current == link, "An invitation received before onboarding survives restarting the app")
        let second = try ClassroomInvitationLink(url: URL(string: "https://www.icloud.com/share/SecondClassToken456")!)
        restored.receive(second.url)
        try check(restored.current == link && restored.links.count == 2, "A second link waits without replacing the class currently being reviewed")
        restored.receive(URL(string: "https://evil.test/share/token")!)
        try check(restored.links.count == 2, "Unrelated app URLs cannot enter the invitation queue")
        restored.finish(link)
        try check(ClassroomInvitationInbox(defaults: defaults).current == second, "Finishing the current invitation persists the next queued link")
        restored.finish(link)
        try check(restored.current == second, "A late completion cannot remove another invitation")
        restored.finish(second)
        try check(ClassroomInvitationInbox(defaults: defaults).current == nil, "Dismissing an invitation does not reopen it at the next launch")

        let receiver = InvitationReceiverStub()
        let model = StudentClassroomInvitationViewModel(link: link, receiver: receiver)
        let premature = await model.join(displayName: "Siswa")
        try check(premature == nil && receiver.joinCalls == 0, "Joining is unavailable before the target class has been verified")
        receiver.failsPreview = true
        await model.load()
        try check(model.invitation == nil && model.errorMessage != nil && !model.isLoading, "Unavailable invitations show an error and allow retry")
        receiver.failsPreview = false
        await model.load()
        try check(model.invitation?.name == "Matematika" && model.errorMessage == nil, "Retry resolves the target class without a manually typed code")
        await model.load()
        try check(receiver.previewCalls == 2, "A loaded preview is reused")
        let emptyName = await model.join(displayName: "  \n ")
        try check(emptyName == nil && receiver.joinCalls == 0, "A blank student name never reaches membership registration")
        receiver.failsJoin = true
        let failedJoin = await model.join(displayName: "  Siswa Satu  ")
        try check(failedJoin == nil && !model.didJoin && !model.isJoining && model.errorMessage != nil, "A failed membership write cannot report a joined class")
        receiver.failsJoin = false
        var concurrentJoinBlocked = false
        receiver.duringJoin = {
            let before = receiver.joinCalls
            let duplicate = await model.join(displayName: "Siswa Duplikat")
            concurrentJoinBlocked = duplicate == nil && receiver.joinCalls == before
        }
        let joined = await model.join(displayName: "  Siswa Satu  ")
        try check(concurrentJoinBlocked, "Repeated join taps cannot register two members")
        try check(joined?.code == model.invitation?.code && receiver.receivedName == "Siswa Satu" && model.didJoin && model.errorMessage == nil,
                  "A successful join retains the intended class and normalized student name")
        let duplicate = await model.join(displayName: "Siswa Satu")
        try check(duplicate == nil && receiver.joinCalls == 2, "A completed invitation cannot be submitted again")
        receiver.cancelsPreview = true
        let cancelled = StudentClassroomInvitationViewModel(link: link, receiver: receiver)
        await cancelled.load()
        try check(cancelled.invitation == nil && cancelled.errorMessage == nil && !cancelled.isLoading, "Leaving during preview does not create a false error or join a class")

        let ownReceiver = InvitationReceiverStub()
        ownReceiver.previewError = ClassroomInvitationValidationError(reason: .ownerAccount)
        let ownModel = StudentClassroomInvitationViewModel(link: link, receiver: ownReceiver)
        await ownModel.load()
        let ownJoin = await ownModel.join(displayName: "Siswa")
        try check(ownModel.invitation == nil && ownJoin == nil && ownReceiver.joinCalls == 0,
                  "A teacher opening their own invitation cannot accidentally register a student member")
        try check(ownModel.errorMessage?.contains("akun iCloud yang berbeda") == true && ownModel.errorDetails?.contains("ownerAccount") == true,
                  "The owner case explains the account issue instead of calling the invitation invalid")
        ownReceiver.previewError = ClassroomInvitationValidationError(reason: .containerMismatch, receivedContainerIdentifier: "iCloud.old")
        await ownModel.load()
        try check(ownModel.errorDetails?.contains("containerMismatch") == true && ownModel.errorDetails?.contains("iCloud.old") == true,
                  "A stale container can be distinguished from the same-account case")
        try check(ownModel.errorDetails?.contains(url.absoluteString) == false && ownModel.errorDetails?.contains("teacher-user") == false,
                  "Copyable diagnostics exclude invitation URLs and iCloud user identifiers")
        ownReceiver.previewError = nil
        await ownModel.load()
        try check(ownModel.invitation != nil && ownModel.errorMessage == nil && ownModel.errorDetails == nil,
                  "A successful retry clears the previous validation diagnostics")
        print("\(checks) Student invitation, onboarding queue, retry, and joining checks passed")
    }
}
