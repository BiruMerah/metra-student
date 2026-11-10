//
//  ChannelViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 06/11/26.
//

import CloudKit
import Foundation
import Observation

@Observable
@MainActor
final class ChannelViewModel {
    // MARK: - Constants
    private let userNameKey = "metra.userName"

    // MARK: - Dependencies
    private let mathMaterialRepository: MathMaterialProtocol
    private let notificationManager: NotificationProtocol
    weak var coordinator: AppCoordinator?
    private let cloudKitManager: CloudKitManager
    @ObservationIgnored var onMaterialsAutosaved: (() -> Void)?
    
    // MARK: - Channel State
    var channels: [ClassroomChannelModel] = []
    var materialsByChannel: [String: [MathMaterialModel]] = [:]
    var isLoadingMaterials: Bool = false
    var savedStatusByMaterialID: [UUID: Bool] = [:]
    var feedbackMessage: String?
    var isShowingJoinSheet: Bool = false
    
    var accountStatusMessage: String = "Memeriksa iCloud..."
    var isSignedInToiCloud: Bool = false
    var isLoading: Bool = false
    var isInitialSyncing: Bool = true
    var hasCompletedInitialSync: Bool = false
    var errorMessage: String?
    
    // MARK: - Profile State
    var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: userNameKey)
        }
    }
    
    var displayName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.generateRandomStudentName() : trimmed
    }
    
    // MARK: - Initialization
    init(
        mathMaterialRepository: MathMaterialProtocol,
        notificationManager: NotificationProtocol,
        coordinator: AppCoordinator? = nil,
        cloudKitManager: CloudKitManager = .shared
    ) {
        self.mathMaterialRepository = mathMaterialRepository
        self.notificationManager = notificationManager
        self.coordinator = coordinator
        self.cloudKitManager = cloudKitManager
        
        if let savedName = UserDefaults.standard.string(forKey: userNameKey),
           !savedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.userName = savedName
        } else {
            let defaultName = Self.generateRandomStudentName()
            self.userName = defaultName
            UserDefaults.standard.set(defaultName, forKey: userNameKey)
        }
    }
    
    private static func generateRandomStudentName() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let randomCode = String((0..<6).compactMap { _ in characters.randomElement() })
        return "Siswa-\(randomCode)"
    }
    
    // MARK: - Channel Actions
    func initialize() async {
        guard !hasCompletedInitialSync else {
            await reloadAllChannels()
            return
        }
        
        isInitialSyncing = true
        isLoading = true
        accountStatusMessage = "Menyinkronkan dengan iCloud..."
        
        defer {
            isInitialSyncing = false
            hasCompletedInitialSync = true
            isLoading = false
        }
        
        await checkAccountStatus()
        guard isSignedInToiCloud else { return }
        
        accountStatusMessage = "Memuat data channel..."
        await reloadAllChannels()
        try? await cloudKitManager.subscribeToChanges()
        accountStatusMessage = "Terhubung ke iCloud"
    }
    
    func checkAccountStatus() async {
        do {
            let status = try await cloudKitManager.checkAccountStatus()
            switch status {
            case .available:
                isSignedInToiCloud = true
                accountStatusMessage = "Terhubung ke iCloud"
            case .noAccount:
                isSignedInToiCloud = false
                accountStatusMessage = "Silakan masuk ke akun iCloud di Pengaturan."
            case .restricted:
                isSignedInToiCloud = false
                accountStatusMessage = "Akun iCloud dibatasi."
            case .couldNotDetermine, .temporarilyUnavailable:
                isSignedInToiCloud = false
                accountStatusMessage = "iCloud sedang tidak tersedia."
            @unknown default:
                isSignedInToiCloud = false
                accountStatusMessage = "Status iCloud tidak diketahui."
            }
        } catch {
            isSignedInToiCloud = false
            accountStatusMessage = "Gagal memeriksa status iCloud"
            errorMessage = "Gagal memeriksa status iCloud: \(error.localizedDescription)"
        }
    }
    
    func reloadAllChannels() async {
        isLoading = true
        defer { isLoading = false }
        
        let savedCodes = cloudKitManager.getSavedChannelCodes()
        guard !savedCodes.isEmpty else {
            channels = []
            materialsByChannel = [:]
            onMaterialsAutosaved?()
            return
        }
        
        var loadedChannels: [ClassroomChannelModel] = []
        var allMaterialsByChannel: [String: [MathMaterialModel]] = [:]
        
        for code in savedCodes {
            if let channel = try? await cloudKitManager.fetchChannel(byCode: code) {
                loadedChannels.append(channel)
                let upperCode = channel.code.uppercased()
                if let fetchedMaterials = try? await cloudKitManager.fetchMaterials(for: upperCode) {
                    allMaterialsByChannel[upperCode] = fetchedMaterials
                    for material in fetchedMaterials {
                        try? mathMaterialRepository.saveMaterial(material)
                        savedStatusByMaterialID[material.id] = true
                    }
                }
            }
        }
        
        self.channels = loadedChannels
        self.materialsByChannel = allMaterialsByChannel
        onMaterialsAutosaved?()
    }
    
    @discardableResult
    func joinChannel(code: String, studentName: String? = nil) async -> ClassroomChannelModel? {
        let student = studentName ?? displayName
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanCode.isEmpty else {
            errorMessage = "Masukkan kode undangan channel."
            return nil
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let channel = try await cloudKitManager.joinChannel(
                code: cleanCode,
                displayMember: student
            )
            upsertChannel(channel)
            let upperCode = channel.code.uppercased()
            if let fetchedMaterials = try? await cloudKitManager.fetchMaterials(for: upperCode) {
                materialsByChannel[upperCode] = fetchedMaterials
                for material in fetchedMaterials {
                    try? mathMaterialRepository.saveMaterial(material)
                    savedStatusByMaterialID[material.id] = true
                }
            }
            onMaterialsAutosaved?()
            return channel
        } catch let ckError as CKError where ckError.code == .unknownItem {
            errorMessage = "Channel dengan kode '\(cleanCode)' tidak ditemukan. Pastikan kode benar."
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func leaveChannel(_ channel: ClassroomChannelModel) {
        cloudKitManager.removeSavedChannelCodeLocally(channel.code)
        channels.removeAll { $0.code == channel.code }
        materialsByChannel.removeValue(forKey: channel.code.uppercased())
    }
    
    // MARK: - Channel Materials Actions
    func loadMaterials(for channel: ClassroomChannelModel) async {
        let code = channel.code.uppercased()
        isLoadingMaterials = true
        defer { isLoadingMaterials = false }
        
        do {
            let fetchedMaterials = try await cloudKitManager.fetchMaterials(for: code)
            materialsByChannel[code] = fetchedMaterials
            
            // Update saved status cache for these materials
            for material in fetchedMaterials {
                if let status = try? mathMaterialRepository.evaluateSaveStatus(for: material) {
                    savedStatusByMaterialID[material.id] = status.isSaved
                }
            }
        } catch {
            errorMessage = "Gagal memuat materi channel: \(error.localizedDescription)"
        }
    }
    
    func isMaterialSavedLocally(_ material: MathMaterialModel) -> Bool {
        if let cached = savedStatusByMaterialID[material.id] {
            return cached
        }
        if let status = try? mathMaterialRepository.evaluateSaveStatus(for: material) {
            savedStatusByMaterialID[material.id] = status.isSaved
            return status.isSaved
        }
        return false
    }
    
    func saveMaterialLocally(_ material: MathMaterialModel) {
        do {
            try mathMaterialRepository.saveMaterial(material)
            savedStatusByMaterialID[material.id] = true
            notificationManager.announceAccessibility("Materi “\(material.title)” berhasil disimpan ke Dokumen")
            feedbackMessage = "Materi “\(material.title)” berhasil disimpan ke Dokumen."
        } catch {
            errorMessage = "Gagal menyimpan materi: \(error.localizedDescription)"
        }
    }
    
    func openMaterialDetail(_ material: MathMaterialModel) {
        coordinator?.navigate(to: .material(material))
    }
    
    private func upsertChannel(_ channel: ClassroomChannelModel) {
        if let idx = channels.firstIndex(where: { $0.code == channel.code }) {
            channels[idx] = channel
        } else {
            channels.insert(channel, at: 0)
        }
    }
}
