//
//  MaterialDetailViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 31/10/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class MaterialDetailViewModel {
    // MARK: - Observable UI State
    let material: MathMaterialModel
    let overview: MaterialOverview
    let topics: [MathTopicModel]
    var isSaved: Bool = false
    var hasDuplicateTitle: Bool = false
    var errorMessage: String?
    private var savedMaterialID: UUID?
    
    var canSave: Bool {
        !isSaved && !hasDuplicateTitle
    }
    
    // MARK: - Dependencies
    private let mathMaterialRepository: MathMaterialProtocol
    private let notificationManager: NotificationProtocol?
    weak var coordinator: (any AppCoordinating)?
    
    init(
        material: MathMaterialModel,
        mathMaterialRepository: MathMaterialProtocol,
        notificationManager: NotificationProtocol? = nil,
        coordinator: (any AppCoordinating)? = nil,
        overview: MaterialOverview? = nil,
        topics: [MathTopicModel]? = nil
    ) {
        self.material = material
        self.mathMaterialRepository = mathMaterialRepository
        self.notificationManager =  notificationManager
        self.coordinator = coordinator
        self.overview = overview ?? mathMaterialRepository.overview(for: material)
        self.topics = topics ?? mathMaterialRepository.topics(for: material)
        
        checkSavedStatus()
    }
    
    // MARK: - Actions
    func checkSavedStatus() {
        errorMessage = nil
        do {
            let savedMaterials = try mathMaterialRepository.fetchSavedMaterials()
            let normalizedTitle = material.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            if let matchedMaterial = savedMaterials.first(where: {
                $0.id == material.id ||
                $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle
            }) {
                self.savedMaterialID = matchedMaterial.id
                self.isSaved = true
                self.hasDuplicateTitle = false
            } else {
                self.savedMaterialID = nil
                self.isSaved = false
                self.hasDuplicateTitle = false
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func saveMaterial() {
        guard canSave else { return }
        errorMessage = nil
        do {
            try mathMaterialRepository.saveMaterial(material)
            checkSavedStatus()
            notificationManager?.announceAccessibility("Materi berhasil disimpan ke pustaka")
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func unsaveMaterial() {
        guard isSaved else { return }
        errorMessage = nil
        do {
            let targetID = savedMaterialID ?? material.id
            try mathMaterialRepository.deleteMaterial(id: targetID)
            checkSavedStatus()
            notificationManager?.announceAccessibility("Materi dihapus dari pustaka")
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Navigation Actions
    func openTopic(at index: Int) {
        guard topics.indices.contains(index) else { return }
        coordinator?.navigate(to: .topicDetail(topics: topics, initialIndex: index))
    }
}
