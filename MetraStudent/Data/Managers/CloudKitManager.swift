//
//  CloudKitManager.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import Foundation
import CloudKit

@MainActor
final class CloudKitManager {
    static let shared = CloudKitManager()
    
    let container = CKContainer.default()
    
    var publicDatabase: CKDatabase {
        container.publicCloudDatabase
    }
    
    var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }
    
    var sharedDatabase: CKDatabase {
        container.sharedCloudDatabase
    }
    
    private let channelRecordType = "ClassroomChannel"
    private let materialRecordType = "SharedMaterial"
    private let savedChannelCodesKey = "metra.savedChannelCodes"
    private let savedChannelNamesKey = "metra.savedChannelNames"
    
    private var cachedUserRecordID: CKRecord.ID?
    
    // MARK: - Account & User Status
    
    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
    
    func fetchCurrentUserRecordID() async throws -> CKRecord.ID {
        if let cached = cachedUserRecordID {
            return cached
        }
        let id = try await container.userRecordID()
        self.cachedUserRecordID = id
        return id
    }
    
    // MARK: - Channel Persistence (UserDefaults)
    func getSavedChannelCodes() -> [String] {
        UserDefaults.standard.stringArray(forKey: savedChannelCodesKey) ?? []
    }
    
    func saveChannelCodeLocally(_ code: String) {
        var saved = getSavedChannelCodes()
        let upper = code.uppercased()
        if !saved.contains(where: { $0.caseInsensitiveCompare(upper) == .orderedSame }) {
            saved.insert(upper, at: 0)
            UserDefaults.standard.set(saved, forKey: savedChannelCodesKey)
        }
    }
    
    func removeSavedChannelCodeLocally(_ code: String) {
        var saved = getSavedChannelCodes()
        saved.removeAll { $0.caseInsensitiveCompare(code) == .orderedSame }
        UserDefaults.standard.set(saved, forKey: savedChannelCodesKey)
        
        var dict = UserDefaults.standard.dictionary(forKey: savedChannelNamesKey) as? [String: String] ?? [:]
        dict.removeValue(forKey: code.uppercased())
        UserDefaults.standard.set(dict, forKey: savedChannelNamesKey)
    }
    
    func saveChannelInfoLocally(code: String, name: String) {
        saveChannelCodeLocally(code)
        var dict = UserDefaults.standard.dictionary(forKey: savedChannelNamesKey) as? [String: String] ?? [:]
        dict[code.uppercased()] = name
        UserDefaults.standard.set(dict, forKey: savedChannelNamesKey)
    }
    
    func getChannelName(for code: String) -> String? {
        let dict = UserDefaults.standard.dictionary(forKey: savedChannelNamesKey) as? [String: String] ?? [:]
        return dict[code.uppercased()]
    }
    
    func getSavedChannels() -> [ChannelTarget] {
        let codes = getSavedChannelCodes()
        let names = UserDefaults.standard.dictionary(forKey: savedChannelNamesKey) as? [String: String] ?? [:]
        return codes.map { code in
            let upper = code.uppercased()
            let name = names[upper] ?? "Channel \(upper)"
            return ChannelTarget(code: upper, name: name)
        }
    }
    
    func refreshSavedChannelNames() async {
        let codes = getSavedChannelCodes()
        for code in codes {
            if let channel = try? await fetchChannel(byCode: code) {
                saveChannelInfoLocally(code: channel.code, name: channel.name)
            }
        }
    }
    
    // MARK: - Channel Materials Local Persistence
    func channelMaterialsKey(for channelCode: String) -> String {
        "channel_materials_\(channelCode.uppercased())"
    }
    
    func getChannelMaterialIDs(for channelCode: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: channelMaterialsKey(for: channelCode)) ?? []
    }
    
    func addMaterial(id: UUID, toChannel channelCode: String) {
        let key = channelMaterialsKey(for: channelCode)
        var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        let idStr = id.uuidString
        if !ids.contains(idStr) {
            ids.append(idStr)
            UserDefaults.standard.set(ids, forKey: key)
        }
    }
    
    func isMaterialShared(id: UUID, inChannel channelCode: String) -> Bool {
        getChannelMaterialIDs(for: channelCode).contains(id.uuidString)
    }
    
    func shareMaterialToCloudKit(material: MathMaterialModel, channelCode: String) async {
        let upperCode = channelCode.uppercased()
        let recordID = CKRecord.ID(recordName: "MATERIAL_\(upperCode)_\(material.id.uuidString)")
        let record = CKRecord(recordType: materialRecordType, recordID: recordID)
        record["channelCode"] = upperCode
        record["materialID"] = material.id.uuidString
        record["title"] = material.title
        record["category"] = material.category
        record["createdAt"] = Date()
        _ = try? await publicDatabase.save(record)
    }
    
    // MARK: - Channel Cloud Operations
    private func fetchChannelRecord(byCode code: String) async throws -> CKRecord? {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let predicate = NSPredicate(format: "code == %@", normalizedCode)
        let query = CKQuery(recordType: channelRecordType, predicate: predicate)
        let records = try await queryRecords(query, from: publicDatabase)
        return records.first
    }
    
    func fetchChannel(byCode code: String) async throws -> ClassroomChannelModel? {
        guard let record = try await fetchChannelRecord(byCode: code) else {
            return nil
        }
        
        let currentUserID = try? await fetchCurrentUserRecordID()
        let ownerRecordID = record["ownerUserRecordID"] as? String
        let isOwner = (ownerRecordID != nil && ownerRecordID == currentUserID?.recordName)
        
        let channel = ClassroomChannelModel(record: record, isOwner: isOwner)
        if let channel = channel {
            saveChannelInfoLocally(code: channel.code, name: channel.name)
        }
        return channel
    }
    
    /// Joins a channel via 6-character code.
    func joinChannel(code: String, displayMember: String) async throws -> ClassroomChannelModel {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard let publicRecord = try await fetchChannelRecord(byCode: cleanCode) else {
            throw NSError(
                domain: "CloudKitManager",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Channel dengan kode '\(cleanCode)' tidak ditemukan. Pastikan kode benar."]
            )
        }
        
        let currentUserID = try? await fetchCurrentUserRecordID()
        let ownerRecordID = publicRecord["ownerUserRecordID"] as? String
        let isOwner = (ownerRecordID != nil && ownerRecordID == currentUserID?.recordName)
        
        if !isOwner,
           let shareURLString = publicRecord["shareURL"] as? String,
           let shareURL = URL(string: shareURLString) {
            try? await acceptShare(at: shareURL)
        }
        
        var currentMembers = publicRecord["members"] as? [String] ?? []
        if !currentMembers.contains(displayMember) {
            currentMembers.append(displayMember)
            publicRecord["members"] = currentMembers
            _ = try? await publicDatabase.save(publicRecord)
        }
        
        guard let channel = ClassroomChannelModel(record: publicRecord, isOwner: isOwner) else {
            throw NSError(
                domain: "CloudKitManager",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Data channel tidak dapat dibaca."]
            )
        }
        
        saveChannelInfoLocally(code: channel.code, name: channel.name)
        return channel
    }
    
    // MARK: - CKShare Acceptance
    func acceptShare(at url: URL) async throws {
        let metadata = try await container.shareMetadata(for: url)
        try await acceptShare(metadata: metadata)
    }
    
    func acceptShare(metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.qualityOfService = .userInitiated
            operation.perShareResultBlock = { _, result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .alreadyShared {
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
            }
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .alreadyShared {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
            self.container.add(operation)
        }
    }
    
    // MARK: - Materials Count Helper
    func countMaterials(for channelCode: String) async -> Int {
        let upperCode = channelCode.uppercased()
        let predicate = NSPredicate(format: "channelCode == %@", upperCode)
        let query = CKQuery(recordType: materialRecordType, predicate: predicate)
        if let records = try? await queryRecords(query, from: publicDatabase) {
            return records.count
        }
        return 0
    }
    
    // MARK: - Subscriptions
    func subscribeToChanges() async throws {
        let subscriptionID = "metra-classroom-changes"
        let predicate = NSPredicate(value: true)
        
        let subscription = CKQuerySubscription(
            recordType: channelRecordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        _ = try? await publicDatabase.save(subscription)
    }
    
    // MARK: - Private Helpers
    private func saveRecordsAtomically(_ records: [CKRecord], to database: CKDatabase) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecord], Error>) in
            let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            op.savePolicy = .changedKeys
            op.qualityOfService = .userInitiated
            
            var savedRecords: [CKRecord] = []
            op.perRecordSaveBlock = { _, result in
                if case .success(let rec) = result {
                    savedRecords.append(rec)
                }
            }
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: savedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }
    
    private func queryRecords(_ query: CKQuery, from database: CKDatabase) async throws -> [CKRecord] {
        let (matchResults, _) = try await database.records(matching: query)
        var records: [CKRecord] = []
        for (_, result) in matchResults {
            if case .success(let rec) = result {
                records.append(rec)
            }
        }
        return records
    }
}

// MARK: - Channel Target (for sharing to specific channels)
struct ChannelTarget: Identifiable, Hashable, Sendable {
    var id: String { code }
    let code: String
    let name: String
    
    var displayName: String {
        name.isEmpty ? "Channel \(code)" : name
    }
}
