//
//  LibraryViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class LibraryViewModel {
    // MARK: - Published variables
    var materials: [MathMaterialModel] = []
    var searchText: String = ""
    var selectedMaterial: MathMaterialModel?
    var errorMessage: String?
    var isLoading: Bool = false
    
    var filteredMaterials: [MathMaterialModel] {
        let sortedMaterials = materials.sorted { $0.createdAt > $1.createdAt }
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return sortedMaterials
        }
        return sortedMaterials.filter {
            $0.title.localizedStandardContains(trimmedQuery)
        }
    }
    
    // MARK: - Dependencies
    private let mathMaterialRepository: MathMaterialProtocol
    weak var coordinator: AppCoordinator?
    
    init(
        mathMaterialRepository: MathMaterialProtocol,
        coordinator: AppCoordinator? = nil
    ) {
        self.mathMaterialRepository = mathMaterialRepository
        self.coordinator = coordinator
    }

    // MARK: - Functions
    func loadMaterials() {
        isLoading = true
        errorMessage = nil
        do {
            self.materials = try mathMaterialRepository.fetchSavedMaterials()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func deleteMaterial(at offsets: IndexSet) {
        let currentMaterials = filteredMaterials
        for index in offsets {
            let item = currentMaterials[index]
            do {
                try mathMaterialRepository.deleteSavedMaterial(id: item.id)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
        loadMaterials() // Refresh list
    }
    
    // MARK: - Navigation Actions
    func openMaterialDetail(_ material: MathMaterialModel) {
        self.selectedMaterial = material
        coordinator?.navigate(to: .materialDetail(material), in: .library)
    }
}
