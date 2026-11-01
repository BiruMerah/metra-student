//
//  ClassroomViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class ClassroomViewModel {
    // MARK: - Observable UI State
    private static let displayNameKey = "savedStudentDisplayName"
    
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
    var selectedMaterial: MathMaterialModel?
    var statusMessage: String = "Idle"
    var errorMessage: String?
    private var hasCompletedInitialSearch: Bool = false
    
    var isStudentConnected: Bool {
        connectedClassroomID != nil
    }
    
    var displayedClassrooms: [DiscoveredClassroom] {
        if let connectedID = connectedClassroomID {
            let connectedList = discoveredClassrooms.filter { $0.id == connectedID }
            if !connectedList.isEmpty {
                return connectedList
            }
            if let name = connectedClassroomName, let teacher = connectedTeacherName {
                return [DiscoveredClassroom(id: connectedID, classroomName: name, teacherName: teacher)]
            }
        }
        return discoveredClassrooms
    }
    
    var emptyClassroomsMessage: String {
        if isSearching {
            return "Sedang mencari ruang kelas di sekitar..."
        } else if !hasCompletedInitialSearch {
            return "Belum ada ruang kelas yang ditemukan"
        } else {
            return statusMessage
        }
    }
    
    // MARK: - Dependencies
    private let networkManager: NetworkProtocol
    private let mathMaterialRepository: MathMaterialProtocol
    private let notificationManager: NotificationProtocol
    private var materialTracker = ClassroomMaterialTracker()
    weak var coordinator: (any AppCoordinating)?
    
    init(
        networkManager: NetworkProtocol,
        mathMaterialRepository: MathMaterialProtocol,
        notificationManager: NotificationProtocol,
        coordinator: (any AppCoordinating)? = nil
    ) {
        self.networkManager = networkManager
        self.mathMaterialRepository = mathMaterialRepository
        self.notificationManager = notificationManager
        self.coordinator = coordinator
        
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
        Task { await notificationManager.requestAuthorizationIfNeeded() }
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
    
    func saveMaterialToLibrary(_ material: MathMaterialModel) {
        do {
            try mathMaterialRepository.saveMaterial(material)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Navigation Actions
    func openMaterialDetail(_ material: MathMaterialModel) {
        self.selectedMaterial = material
        coordinator?.navigate(to: .materialDetail(material), in: .classroom)
    }
    
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
                self.hasCompletedInitialSearch = true
                self.statusMessage = "Gagal mencari ruang kelas: \(message)"
                
            case .classroomUpdated(let updatedClassrooms):
                let previousIDs = Set(self.discoveredClassrooms.map(\.id))
                self.discoveredClassrooms = updatedClassrooms
                if !self.isStudentConnected && self.connectingClassroomIDs.isEmpty {
                    self.statusMessage = updatedClassrooms.isEmpty
                    ? "Sedang mencari ruang kelas..."
                    : "\(updatedClassrooms.count) ruang kelas ditemukan"
                }
                for item in updatedClassrooms where !previousIDs.contains(item.id) {
                    self.notificationManager.announceAccessibility("Ruang kelas \(item.classroomName) ditemukan")
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
                self.notificationManager.announceAccessibility("Telah tergabung ke dalam \(discoveredClassroom.classroomName)")
                
            case .classroomSynced(let classroomID, let classroomName, let teacherName, let materials):
                let newMaterials = self.materialTracker.newMaterials(in: materials, classroomID: classroomID)
                self.connectingClassroomIDs.remove(classroomID)
                self.connectedClassroomID = classroomID
                self.connectedClassroomName = classroomName
                self.connectedTeacherName = teacherName
                self.receivedMaterials = materials
                self.statusMessage = "\(materials.count) materi tersedia"
                if !newMaterials.isEmpty {
                    self.notificationManager.notifyNewMaterials(
                        newMaterials,
                        classroomID: classroomID,
                        classroomName: classroomName
                    )
                }
                
            case .classroomDisconnected(let classroomID):
                let wasConnecting = self.connectingClassroomIDs.remove(classroomID) != nil
                if self.connectedClassroomID == classroomID || wasConnecting {
                    self.connectedClassroomID = nil
                    self.connectedClassroomName = nil
                    self.connectedTeacherName = nil
                    self.receivedMaterials.removeAll()
                    self.hasCompletedInitialSearch = false
                    self.statusMessage = "Disconnected"
                }
                
            case .leftClassroom:
                self.connectedClassroomID = nil
                self.connectingClassroomIDs.removeAll()
                self.connectedClassroomName = nil
                self.connectedTeacherName = nil
                self.receivedMaterials.removeAll()
                self.hasCompletedInitialSearch = false
                self.statusMessage = self.isSearching ? "Sedang mencari ruang kelas..." : "Disconnected"
                
            case .resetAll:
                self.materialTracker.reset()
                self.isSearching = false
                self.hasCompletedInitialSearch = false
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
