//
//  MaterialDetailViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 31/10/26.
//

import Foundation
import Observation
import SwiftUI

nonisolated struct MaterialOverview {
    let chapter: String
    let subchapter: String
    let pageNumber: Int
    let questionCount: Int

    // Presentation fixture until classroom materials include document metadata.
    static let sample = MaterialOverview(
        chapter: "Bab I - Persamaan Linear Satu Variabel",
        subchapter: "Mengenal dan Menyelesaikan Persamaan Linear",
        pageNumber: 21,
        questionCount: 1
    )
}

@Observable
@MainActor
final class MaterialDetailViewModel {
    // MARK: - Observable UI State
    let material: MathMaterialModel
    let overview: MaterialOverview
    var isSaved: Bool = false
    var hasDuplicateTitle: Bool = false
    var errorMessage: String?
    
    var canSave: Bool {
        !isSaved && !hasDuplicateTitle
    }
    
    // MARK: - Dependencies
    private let mathMaterialRepository: MathMaterialProtocol
    
    init(
        material: MathMaterialModel,
        mathMaterialRepository: MathMaterialProtocol,
        overview: MaterialOverview? = nil
    ) {
        self.material = material
        self.overview = overview ?? .sample
        self.mathMaterialRepository = mathMaterialRepository
        checkSavedStatus()
    }
    
    // MARK: - Actions
    func checkSavedStatus() {
        errorMessage = nil
        do {
            let savedMaterials = try mathMaterialRepository.fetchSavedMaterials()
            self.isSaved = savedMaterials.contains { $0.id == material.id }
            
            let normalizedTitle = material.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            self.hasDuplicateTitle = savedMaterials.contains {
                $0.id != material.id &&
                $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func saveMaterial() {
        guard canSave else { return }
        errorMessage = nil
        do {
            try mathMaterialRepository.addSavedMaterial(material: material)
            checkSavedStatus()
            AccessibilityNotification.Announcement("Materi berhasil disimpan ke pustaka").post()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func unsaveMaterial() {
        guard isSaved else { return }
        errorMessage = nil
        do {
            try mathMaterialRepository.deleteSavedMaterial(id: material.id)
            checkSavedStatus()
            AccessibilityNotification.Announcement("Materi dihapus dari pustaka").post()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
