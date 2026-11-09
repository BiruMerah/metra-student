//
//  MaterialViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 09/11/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class MaterialViewModel {
    // MARK: - Observable UI State
    let material: MathMaterialModel
    let overview: MaterialOverview
    let sections: [MathSectionModel]
    var selectedSpeechStyle: SpeechStyle
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
    weak var coordinator: AppCoordinator?
    
    init(
        material: MathMaterialModel,
        mathMaterialRepository: MathMaterialProtocol,
        notificationManager: NotificationProtocol? = nil,
        coordinator: AppCoordinator? = nil,
        overview: MaterialOverview? = nil,
        sections: [MathSectionModel]? = nil
    ) {
        self.material = material
        self.mathMaterialRepository = mathMaterialRepository
        self.notificationManager =  notificationManager
        self.coordinator = coordinator
        self.selectedSpeechStyle = material.defaultSpeechStyle
        self.overview = overview ?? mathMaterialRepository.overview(for: material)
        self.sections = sections ?? mathMaterialRepository.sections(for: material)
        
        checkSavedStatus()
    }
    
    // MARK: - Actions
    func checkSavedStatus() {
        errorMessage = nil
        do {
            let status = try mathMaterialRepository.evaluateSaveStatus(for: material)
            savedMaterialID = status.isSaved ? material.id : nil
            isSaved = status.isSaved
            hasDuplicateTitle = status.hasDuplicateTitle
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
    
    func removeSavedMaterial() {
        guard isSaved else { return }
        errorMessage = nil
        do {
            let targetID = savedMaterialID ?? material.id
            try mathMaterialRepository.deleteMaterial(id: targetID)
            isSaved = false
            savedMaterialID = nil
            notificationManager?.announceAccessibility("Dokumen dihapus.")
            coordinator?.navigateBack()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Navigation Actions
    func openSection(at index: Int) {
        guard sections.indices.contains(index) else { return }
        coordinator?.navigate(
            to: .section(
                sections: sections,
                initialIndex: index,
                speechStyle: selectedSpeechStyle
            )
        )
    }
}
