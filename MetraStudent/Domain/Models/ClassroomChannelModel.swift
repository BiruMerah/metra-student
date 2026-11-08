//
//  ClassroomChannelModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import Foundation
import CloudKit

struct ClassroomChannelModel: Identifiable, Hashable, Sendable {
    let recordID: CKRecord.ID
    var id: String { code }
    
    let code: String
    let name: String
    let createdBy: String
    let createdAt: Date
    let members: [String]
    let shareURL: URL?
    let ownerUserRecordID: String?
    let isOwner: Bool
    
    init(
        recordID: CKRecord.ID? = nil,
        code: String,
        name: String,
        createdBy: String,
        createdAt: Date = Date(),
        members: [String] = [],
        shareURL: URL? = nil,
        ownerUserRecordID: String? = nil,
        isOwner: Bool = false
    ) {
        let normalizedCode = code.uppercased()
        self.recordID = recordID ?? CKRecord.ID(recordName: normalizedCode)
        self.code = normalizedCode
        self.name = name
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.members = members
        self.shareURL = shareURL
        self.ownerUserRecordID = ownerUserRecordID
        self.isOwner = isOwner
    }
    
    init?(record: CKRecord, isOwner: Bool = false) {
        guard let code = record["code"] as? String,
              let name = record["name"] as? String else {
            return nil
        }
        self.recordID = record.recordID
        self.code = code.uppercased()
        self.name = name
        self.createdBy = record["createdBy"] as? String ?? "Unknown"
        self.createdAt = record["createdAt"] as? Date ?? record.creationDate ?? Date()
        self.members = record["members"] as? [String] ?? []
        
        if let urlStr = record["shareURL"] as? String, let url = URL(string: urlStr) {
            self.shareURL = url
        } else {
            self.shareURL = nil
        }
        self.ownerUserRecordID = record["ownerUserRecordID"] as? String
        self.isOwner = isOwner
    }
    
    func updating(isOwner: Bool) -> ClassroomChannelModel {
        ClassroomChannelModel(
            recordID: self.recordID,
            code: self.code,
            name: self.name,
            createdBy: self.createdBy,
            createdAt: self.createdAt,
            members: self.members,
            shareURL: self.shareURL,
            ownerUserRecordID: self.ownerUserRecordID,
            isOwner: isOwner
        )
    }
    
    func updating(members: [String]) -> ClassroomChannelModel {
        ClassroomChannelModel(
            recordID: self.recordID,
            code: self.code,
            name: self.name,
            createdBy: self.createdBy,
            createdAt: self.createdAt,
            members: members,
            shareURL: self.shareURL,
            ownerUserRecordID: self.ownerUserRecordID,
            isOwner: self.isOwner
        )
    }
    
    func removing(member: String) -> ClassroomChannelModel {
        var updated = self.members
        updated.removeAll { $0 == member }
        return updating(members: updated)
    }
}
