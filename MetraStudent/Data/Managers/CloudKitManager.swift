//
//  CloudKitManager.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import Foundation
import CloudKit

@MainActor
final class CloudKitManager: ClassroomInvitationReceiving {
    static let shared = CloudKitManager()

    enum JoinError: LocalizedError {
        case notFound(String)
        case unreadable

        var errorDescription: String? {
            switch self {
            case .notFound(let code): "Kelas dengan kode \(code) tidak ditemukan. Periksa kode undangan dari guru."
            case .unreadable: "Informasi kelas belum bisa dibaca. Minta guru memeriksa kelas tersebut."
            }
        }
    }
    
    // Runtime metadata and signed entitlements use the same Xcode build setting.
    let container = ClassroomInvitationContract.containerIdentifier.map { CKContainer(identifier: $0) } ?? CKContainer.default()
    
    var publicDatabase: CKDatabase {
        container.publicCloudDatabase
    }
    
    var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }
    
    var sharedDatabase: CKDatabase {
        container.sharedCloudDatabase
    }
    
    private let classroomChannelRecordType = "ClassroomChannel"
    private let sharedMaterialRecordType = "SharedMaterial"
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
            let name = names[upper] ?? "Kelas \(upper)"
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
        let record = CKRecord(recordType: sharedMaterialRecordType, recordID: recordID)
        record["channelCode"] = upperCode
        record["materialID"] = material.id.uuidString
        record["title"] = material.title
        record["category"] = material.category
        record["overview"] = material.overview ?? ""
        record["defaultSpeechStyle"] = material.defaultSpeechStyle.rawValue
        record["reviewStatus"] = material.reviewStatus.rawValue
        record["revision"] = material.revision
        record["format"] = "metra.material"
        record["schemaVersion"] = 1
        record["createdAt"] = material.createdAt
        record["updatedAt"] = Date()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        if let encodedData = try? encoder.encode(material),
           let jsonString = String(data: encodedData, encoding: .utf8) {
            record["content"] = jsonString
        } else {
            record["content"] = material.content
        }
        
        do {
            let saved = try await publicDatabase.save(record)
            print("✅ [CloudKit] Siswa berhasil membagikan materi '\(material.title)' ke channel \(upperCode): \(saved.recordID.recordName)")
        } catch {
            print("❌ [CloudKit] Gagal membagikan materi '\(material.title)' ke channel \(upperCode): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Channel Cloud Operations
    private func fetchChannelRecord(byCode code: String) async throws -> CKRecord? {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let predicate = NSPredicate(format: "code == %@", normalizedCode)
        let query = CKQuery(recordType: classroomChannelRecordType, predicate: predicate)
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
            throw JoinError.notFound(cleanCode)
        }
        
        if let shareURLString = publicRecord["shareURL"] as? String,
           let shareURL = URL(string: shareURLString) {
            try? await acceptShare(at: shareURL)
        }
        return try await registerMember(displayMember, in: publicRecord)
    }

    private func registerMember(_ displayMember: String, in initialRecord: CKRecord,
                                requiredLink: ClassroomInvitationLink? = nil) async throws -> ClassroomChannelModel {
        let userID = try await fetchCurrentUserRecordID()
        var record = initialRecord
        for attempt in 0..<3 {
            if let requiredLink { try requireCurrentInvitation(requiredLink, for: record) }
            var members = record["members"] as? [String] ?? []
            if !members.contains(displayMember) {
                members.append(displayMember)
                record["members"] = members
                do { record = try await publicDatabase.save(record) }
                catch let error as CKError where error.code == .serverRecordChanged && attempt < 2 {
                    record = try await publicDatabase.record(for: record.recordID)
                    continue
                }
            }
            let owner = record.creatorUserRecordID?.recordName ?? record["ownerUserRecordID"] as? String
            guard let channel = ClassroomChannelModel(record: record, isOwner: owner == userID.recordName) else {
                throw JoinError.unreadable
            }
            // Only report a joined class after its membership is committed.
            saveChannelInfoLocally(code: channel.code, name: channel.name)
            return channel
        }
        throw CKError(.serverRecordChanged)
    }

    // MARK: - Invitation links

    func previewInvitation(_ link: ClassroomInvitationLink) async throws -> ReceivedClassroomInvitation {
        let (_, record) = try await invitationContext(for: link)
        guard let code = record["code"] as? String, let name = record["name"] as? String else {
            throw ClassroomInvitationError.unavailable
        }
        return .init(link: link, channelRecordName: record.recordID.recordName, code: code,
            name: name, teacherName: record["createdBy"] as? String ?? "Guru")
    }

    func joinInvitation(_ invitation: ReceivedClassroomInvitation, displayMember: String) async throws -> ClassroomChannelModel {
        let (metadata, record) = try await invitationContext(for: invitation.link)
        guard record.recordID.recordName == invitation.channelRecordName,
              record["code"] as? String == invitation.code else { throw ClassroomInvitationError.unavailable }
        try await acceptShare(metadata: metadata)
        do { return try await registerMember(displayMember, in: record, requiredLink: invitation.link) }
        catch let error as CKError where error.code == .unknownItem { throw ClassroomInvitationError.unavailable }
    }

    private func invitationContext(for link: ClassroomInvitationLink) async throws -> (CKShare.Metadata, CKRecord) {
        guard try await checkAccountStatus() == .available else { throw ClassroomInvitationError.iCloudRequired }
        let metadata: CKShare.Metadata
        do { metadata = try await invitationMetadata(for: link.url) }
        catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound || error.code == .permissionFailure {
            throw ClassroomInvitationError.unavailable
        }
        try Task.checkCancellation()
        try ClassroomInvitationValidation.validateContainer(metadata.containerIdentifier, expected: container.containerIdentifier)
        try ClassroomInvitationValidation.validateShareType(metadata.share[CKShare.SystemFieldKey.shareType] as? String)
        let currentUser = try await fetchCurrentUserRecordID().recordName
        // Opening one's own share is not accepting an invitation as another user.
        // Explain that case before interpreting participant-only preview data.
        try ClassroomInvitationValidation.requireRecipient(isShareOwner: metadata.participantRole == .owner,
            shareOwnerRecordName: metadata.ownerIdentity.userRecordID?.recordName, currentUserRecordName: currentUser)
        let payload = try ClassroomInvitationValidation.payload(from: metadata.rootRecord)
        let record: CKRecord
        do { record = try await publicDatabase.record(for: CKRecord.ID(recordName: payload.channelRecordName)) }
        catch let error as CKError where error.code == .unknownItem { throw ClassroomInvitationError.unavailable }
        guard record.recordType == classroomChannelRecordType, record["code"] as? String == payload.code else {
            throw ClassroomInvitationError.unavailable
        }
        try ClassroomInvitationValidation.validateOwner(classCreator: record.creatorUserRecordID?.recordName,
            storedClassOwner: record["ownerUserRecordID"] as? String,
            shareOwner: metadata.ownerIdentity.userRecordID?.recordName,
            zoneOwner: payload.zoneOwner, currentUser: currentUser)
        try requireCurrentInvitation(link, for: record)
        return (metadata, record)
    }

    private func requireCurrentInvitation(_ link: ClassroomInvitationLink, for record: CKRecord) throws {
        guard let rawURL = record["shareURL"] as? String, let url = URL(string: rawURL),
              let current = try? ClassroomInvitationLink(url: url), current == link else {
            throw ClassroomInvitationError.unavailable
        }
    }

    /// Fetch the invitation preview without joining the share or adding a member.
    private func invitationMetadata(for url: URL) async throws -> CKShare.Metadata {
        let operation = CKFetchShareMetadataOperation(shareURLs: [url])
        operation.shouldFetchRootRecord = true
        operation.rootRecordDesiredKeys = ["schemaVersion", "channelCode", "channelRecordName", "name", "createdBy"]
        operation.qualityOfService = .userInitiated
        let resultBox = InvitationMetadataResultBox()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                operation.perShareMetadataResultBlock = { _, result in resultBox.store(result) }
                // Complete once, from the overall operation callback only.
                operation.fetchShareMetadataResultBlock = { result in
                    switch result {
                    case .success: continuation.resume(with: resultBox.result() ?? .failure(CKError(.internalError)))
                    case .failure(let error):
                        if case .failure(let itemError)? = resultBox.result() { continuation.resume(throwing: itemError) }
                        else { continuation.resume(throwing: error) }
                    }
                }
                container.add(operation)
            }
        } onCancel: { operation.cancel() }
    }
    
    // MARK: - CKShare Acceptance
    func acceptShare(at url: URL) async throws {
        let metadata = try await container.shareMetadata(for: url)
        try await acceptShare(metadata: metadata)
    }
    
    func acceptShare(metadata: CKShare.Metadata) async throws {
        guard metadata.containerIdentifier == container.containerIdentifier else {
            throw ClassroomInvitationError.wrongContainer
        }
        guard metadata.participantRole != .owner, metadata.participantStatus != .accepted else { return }
        _ = try await container.accept(metadata)
    }
    
    // MARK: - Materials Count & Fetch Helpers
    func countMaterials(for channelCode: String) async -> Int {
        let upperCode = channelCode.uppercased()
        let predicate = NSPredicate(format: "channelCode == %@", upperCode)
        let query = CKQuery(recordType: sharedMaterialRecordType, predicate: predicate)
        if let records = try? await queryRecords(query, from: publicDatabase) {
            return records.count
        }
        return 0
    }
    
    func fetchMaterials(for channelCode: String) async throws -> [MathMaterialModel] {
        let upperCode = channelCode.uppercased()
        let predicate = NSPredicate(format: "channelCode == %@", upperCode)
        let query = CKQuery(recordType: sharedMaterialRecordType, predicate: predicate)
        let records = try await queryRecords(query, from: publicDatabase)
        
        let materials = records.compactMap { parseMaterial(from: $0) }
        return materials.sorted { $0.createdAt > $1.createdAt }
    }
    
    private func parseMaterial(from record: CKRecord) -> MathMaterialModel? {
        decodeMaterial(from: record)?.withTeacherSource()
    }

    private func decodeMaterial(from record: CKRecord) -> MathMaterialModel? {
        guard let title = record["title"] as? String else { return nil }
        let idString = record["materialID"] as? String ?? record.recordID.recordName
        let id = UUID(uuidString: idString) ?? UUID()
        let category = record["category"] as? String ?? "Materi"
        let createdAt = record["createdAt"] as? Date ?? record.creationDate ?? Date()
        let overview = record["overview"] as? String
        let revision = (record["revision"] as? Int) ?? 1
        let defaultSpeechStyle = SpeechStyle(rawValue: record["defaultSpeechStyle"] as? String ?? "") ?? .clearSpeak
        let reviewStatus = ReviewStatus(rawValue: record["reviewStatus"] as? String ?? "") ?? .draft
        let validatedAt = record["validatedAt"] as? Date
        
        if let contentStr = record["content"] as? String,
           let data = contentStr.data(using: .utf8) {
            
            let isoDecoder = JSONDecoder()
            isoDecoder.dateDecodingStrategy = .iso8601
            
            // Try decoding as PortableEnvelope (from Teacher app via MetraMaterialFile)
            if let envelope = try? isoDecoder.decode(PortableEnvelope.self, from: data) {
                return envelope.material.studentMaterial
            }
            
            // Try decoding as direct MetraPortableMaterial
            if let portable = try? isoDecoder.decode(PortableMaterial.self, from: data) {
                return portable.studentMaterial
            }
            
            //Try standard JSONDecoder for MathMaterialModel
            let standardDecoder = JSONDecoder()
            if let model = try? standardDecoder.decode(MathMaterialModel.self, from: data) {
                return model
            }
            
            // Try decoding as [MathSectionModel]
            if let sections = try? standardDecoder.decode([MathSectionModel].self, from: data) {
                return MathMaterialModel(
                    id: id,
                    title: title,
                    category: category,
                    content: contentStr,
                    createdAt: createdAt,
                    revision: revision,
                    defaultSpeechStyle: defaultSpeechStyle,
                    reviewStatus: reviewStatus,
                    validatedAt: validatedAt,
                    overview: overview,
                    sections: sections
                )
            }
            
            let trimmed = contentStr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return MathMaterialModel(
                    id: id,
                    title: title,
                    category: category,
                    content: trimmed,
                    createdAt: createdAt,
                    revision: revision,
                    defaultSpeechStyle: defaultSpeechStyle,
                    reviewStatus: reviewStatus,
                    validatedAt: validatedAt,
                    overview: overview,
                    sections: [MathSectionModel(title: title, content: [.text(trimmed)])]
                )
            }
        }
        
        return MathMaterialModel(
            id: id,
            title: title,
            category: category,
            content: "",
            createdAt: createdAt,
            revision: revision,
            defaultSpeechStyle: defaultSpeechStyle,
            reviewStatus: reviewStatus,
            validatedAt: validatedAt,
            overview: overview,
            sections: []
        )
    }
    
    // MARK: - Subscriptions
    func subscribeToChanges() async throws {
        let channelSubscriptionID = "metra-classroom-changes"
        let materialSubscriptionID = "metra-materials-changes"
        let predicate = NSPredicate(value: true)
        
        let channelSubscription = CKQuerySubscription(
            recordType: classroomChannelRecordType,
            predicate: predicate,
            subscriptionID: channelSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        let channelNotificationInfo = CKSubscription.NotificationInfo()
        channelNotificationInfo.shouldSendContentAvailable = true
        channelSubscription.notificationInfo = channelNotificationInfo
        _ = try? await publicDatabase.save(channelSubscription)
        
        let materialSubscription = CKQuerySubscription(
            recordType: sharedMaterialRecordType,
            predicate: predicate,
            subscriptionID: materialSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        let materialNotificationInfo = CKSubscription.NotificationInfo()
        materialNotificationInfo.shouldSendContentAvailable = true
        materialSubscription.notificationInfo = materialNotificationInfo
        _ = try? await publicDatabase.save(materialSubscription)
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
        name.isEmpty ? "Kelas \(code)" : name
    }
}
