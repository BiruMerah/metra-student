import CloudKit
import CryptoKit
import Foundation

/// Public membership rows are created and updated only by their own iCloud user.
/// ClassroomChannel remains writable only by its teacher/creator.
struct ClassroomMembership: Equatable, Sendable {
    static let recordType = "ClassroomMembership"
    static let removedMembershipsKey = "removedMemberships"

    let channelRecordName: String
    let channelCode: String
    let memberUserRecordID: String
    let displayName: String
    let enrollmentID: String
    let joinedAt: Date

    var recordID: CKRecord.ID {
        Self.recordID(channelRecordName: channelRecordName, memberUserRecordID: memberUserRecordID)
    }

    /// Identifies one enrollment, so a removal doesn't reappear on refresh.
    /// An explicit rejoin may start a new enrollment in the same user's row.
    var enrollmentKey: String { "\(recordID.recordName):\(enrollmentID)" }

    static func recordID(channelRecordName: String, memberUserRecordID: String) -> CKRecord.ID {
        // JSON framing prevents ambiguous concatenations of the two identifiers.
        let bytes = try! JSONEncoder().encode([channelRecordName, memberUserRecordID])
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        return CKRecord.ID(recordName: "MEMBERSHIP_\(digest)")
    }

    init(channelRecordName: String, channelCode: String, memberUserRecordID: String,
         displayName: String, enrollmentID: String = UUID().uuidString, joinedAt: Date = Date()) {
        self.channelRecordName = channelRecordName
        self.channelCode = channelCode.uppercased()
        self.memberUserRecordID = memberUserRecordID
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.enrollmentID = enrollmentID
        self.joinedAt = joinedAt
    }

    init?(record: CKRecord, currentUserRecordName: String?) {
        guard record.recordType == Self.recordType,
              record.recordID.zoneID == CKRecordZone.default().zoneID,
              let channel = record["channelRecordName"] as? String, !channel.isEmpty,
              let code = record["channelCode"] as? String, !code.isEmpty,
              let user = record["memberUserRecordID"] as? String, !user.isEmpty,
              let name = record["displayName"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let enrollment = record["enrollmentID"] as? String, UUID(uuidString: enrollment) != nil,
              let joinedAt = record["joinedAt"] as? Date,
              let creator = record.creatorUserRecordID?.recordName else { return nil }
        guard Self.authentic(recordID: record.recordID, channelRecordName: channel, memberUserRecordID: user,
                             creatorRecordName: creator, currentUserRecordName: currentUserRecordName) else { return nil }
        self.init(channelRecordName: channel, channelCode: code, memberUserRecordID: user,
                  displayName: name, enrollmentID: enrollment, joinedAt: joinedAt)
    }

    func applying(to record: CKRecord) {
        record["channelRecordName"] = channelRecordName
        record["channelCode"] = channelCode
        record["memberUserRecordID"] = memberUserRecordID
        record["displayName"] = displayName
        record["enrollmentID"] = enrollmentID
        record["joinedAt"] = joinedAt
    }

    static func authentic(recordID: CKRecord.ID, channelRecordName: String, memberUserRecordID: String,
                          creatorRecordName: String?, currentUserRecordName: String?) -> Bool {
        let creator = creatorRecordName == CKCurrentUserDefaultName ? currentUserRecordName : creatorRecordName
        return creator != nil && creator == memberUserRecordID
            && recordID == Self.recordID(channelRecordName: channelRecordName, memberUserRecordID: memberUserRecordID)
    }

    static func registration(existing: Self?, channelRecordName: String, channelCode: String,
                             memberUserRecordID: String, displayName: String,
                             removedMemberships: Set<String>, now: Date = Date()) -> Self {
        let reusable = existing.flatMap { previous -> Self? in
            guard previous.channelRecordName == channelRecordName,
                  previous.channelCode == channelCode.uppercased(),
                  previous.memberUserRecordID == memberUserRecordID,
                  !removedMemberships.contains(previous.enrollmentKey) else { return nil }
            return previous
        }
        return Self(channelRecordName: channelRecordName, channelCode: channelCode,
                    memberUserRecordID: memberUserRecordID, displayName: displayName,
                    enrollmentID: reusable?.enrollmentID ?? UUID().uuidString,
                    joinedAt: reusable?.joinedAt ?? now)
    }

    static func active(in records: [Self], channelRecordName: String, channelCode: String,
                       removedMemberships: Set<String>) -> [Self] {
        records.filter {
            $0.channelRecordName == channelRecordName && $0.channelCode == channelCode.uppercased()
                && !removedMemberships.contains($0.enrollmentKey)
        }.sorted {
            if $0.joinedAt != $1.joinedAt { return $0.joinedAt < $1.joinedAt }
            return $0.recordID.recordName < $1.recordID.recordName
        }
    }

    static func roster(legacyMembers: [String], memberships: [Self]) -> [String] {
        var result: [String] = []
        for name in legacyMembers + memberships.map(\.displayName) {
            if !name.isEmpty && !result.contains(name) { result.append(name) }
        }
        return result
    }
}
