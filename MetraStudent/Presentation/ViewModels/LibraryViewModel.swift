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
    // MARK: - Observable UI State
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
    weak var coordinator: (any AppCoordinating)?
    
    init(
        mathMaterialRepository: MathMaterialProtocol,
        coordinator: (any AppCoordinating)? = nil
    ) {
        self.mathMaterialRepository = mathMaterialRepository
        self.coordinator = coordinator
    }
    
    // MARK: - Action Functions
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
                try mathMaterialRepository.deleteMaterial(id: item.id)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
        loadMaterials()
    }
    
    func openMaterialDetail(_ material: MathMaterialModel) {
        self.selectedMaterial = material
        coordinator?.navigate(to: .materialDetail(material), in: .library)
    }
}
