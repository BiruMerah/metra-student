//
//  ClassroomViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
@MainActor
final class ClassroomViewModel {
    private static let displayNameKey = "savedStudentDisplayName"
    
    // MARK: - Observable UI State
    var displayName: String {
        didSet {
            UserDefaults.standard.set(displayName, forKey: Self.displayNameKey)
        }
    }
    var isSearching: Bool = false
    var discoveredClassrooms: [DiscoveredClassroom] = []
    var connectedClassroomID: String?
    var connectingClassroomIDs: Set<String> = []
    var connectedClassroomName: String?
    var connectedTeacherName: String?
    var receivedMaterials: [MathMaterialModel] = []
    var statusMessage: String = "Idle"
    var errorMessage: String?
    var isStudentConnected: Bool {
        connectedClassroomID != nil
    }
    
    // MARK: - Dependencies
    private let networkManager: NetworkProtocol
    private let mathMaterialRepository: MathMaterialProtocol
    
    init(networkManager: NetworkProtocol, mathMaterialRepository: MathMaterialProtocol) {
        self.networkManager = networkManager
        self.mathMaterialRepository = mathMaterialRepository
        
        let savedName = UserDefaults.standard.string(forKey: Self.displayNameKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultName = UIDevice.current.name // TODO - Need to sign restrict privacy entitlement for iOS 16+ version
        self.displayName = (savedName?.isEmpty == false) ? savedName! : defaultName
        
        bindNetworkEvents()
    }
    
    // MARK: - Network Actions
    func onAppear() {
        networkManager.ensureSearchingIfNeeded()
    }
    
    func startSearching() {
        networkManager.startSearchingClassrooms()
    }
    
    func joinClassroom(_ discoveredClassroom: DiscoveredClassroom) {
        networkManager.joinClassroom(discoveredClassroom, studentName: displayName)
    }
    
    func leaveCurrentClassroom() {
        networkManager.leaveCurrentClassroom()
    }
    
    func stopAll() {
        networkManager.stopAll()
    }
    
    func connectionState(for discoveredClassroom: DiscoveredClassroom) -> ClassroomConnectionState {
        if connectedClassroomID == discoveredClassroom.id {
            return .connected
        } else if connectingClassroomIDs.contains(discoveredClassroom.id) {
            return .connecting
        } else {
            return .notConnected
        }
    }
    
    // TODO - Code checking
    func saveMaterialToLibrary(_ material: MathMaterialModel) {
        do {
            try mathMaterialRepository.addSavedMaterial(material: material)
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // TODO - Code checking
    private func bindNetworkEvents() {
        networkManager.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .searchingChanged(let searching):
                self.isSearching = searching
                if searching && !self.isStudentConnected {
                    self.statusMessage = "Sedang mencari ruang kelas..."
                }
                
            case .searchFailed(let message):
                self.isSearching = false
                self.statusMessage = "Gagal mencari ruang kelas: \(message)"
                
            case .classroomUpdated(let updatedClasrooms):
                let previousIDs = Set(self.discoveredClassrooms.map(\.id))
                self.discoveredClassrooms = updatedClasrooms
                if !self.isStudentConnected && self.connectingClassroomIDs.isEmpty {
                    self.statusMessage = updatedClasrooms.isEmpty
                        ? "Sedang mencari ruang kelas..."
                        : "\(updatedClasrooms.count) ruang kelas ditemukan"
                }
                for item in updatedClasrooms where !previousIDs.contains(item.id) {
                    AccessibilityNotification.Announcement("Ruang kelas \(item.classroomName) ditemukan").post()
                }
                
            case .classroomConnecting(let discoveredClassroom):
                self.connectedClassroomID = nil
                self.connectingClassroomIDs = [discoveredClassroom.id]
                self.connectedClassroomName = discoveredClassroom.classroomName
                self.connectedTeacherName = discoveredClassroom.teacherName
                self.receivedMaterials.removeAll()
                self.statusMessage = "Bergabung ke dalam ruang kelas \(discoveredClassroom.classroomName)..."
                
            case .classroomConnected(let discoveredClassroom):
                self.connectingClassroomIDs.remove(discoveredClassroom.id)
                self.connectedClassroomID = discoveredClassroom.id
                self.connectedClassroomName = discoveredClassroom.classroomName
                self.connectedTeacherName = discoveredClassroom.teacherName
                self.statusMessage = "Telah tergabung ke dalam \(discoveredClassroom.classroomName)"
                AccessibilityNotification.Announcement("Telah tergabung ke dalam \(discoveredClassroom.classroomName)").post()
                
            case .classroomSynced(let classroomID, let classroomName, let teacherName, let materials):
                self.connectingClassroomIDs.remove(classroomID)
                self.connectedClassroomID = classroomID
                self.connectedClassroomName = classroomName
                self.connectedTeacherName = teacherName
                self.receivedMaterials = materials
                self.statusMessage = "\(materials.count) Materials"
                AccessibilityNotification.Announcement("Terdapat \(materials.count) materials yang tersedia").post()
                
            case .classroomDisconnected(let classroomID):
                let wasConnecting = self.connectingClassroomIDs.remove(classroomID) != nil
                if self.connectedClassroomID == classroomID || wasConnecting {
                    self.connectedClassroomID = nil
                    self.connectedClassroomName = nil
                    self.connectedTeacherName = nil
                    self.receivedMaterials.removeAll()
                    self.statusMessage = "Disconnected"
                }
                
            case .leftClassroom:
                self.connectedClassroomID = nil
                self.connectingClassroomIDs.removeAll()
                self.connectedClassroomName = nil
                self.connectedTeacherName = nil
                self.receivedMaterials.removeAll()
                self.statusMessage = self.isSearching ? "Sedang mencari ruang kelas..." : "Disconnected"
                
            case .resetAll:
                self.isSearching = false
                self.discoveredClassrooms.removeAll()
                self.connectedClassroomID = nil
                self.connectingClassroomIDs.removeAll()
                self.connectedClassroomName = nil
                self.connectedTeacherName = nil
                self.receivedMaterials.removeAll()
                self.statusMessage = "Idle"
            }
        }
    }
}
