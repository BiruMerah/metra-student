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
    var selectedMaterial: MathMaterialModel?
    var errorMessage: String?
    var isLoading: Bool = false
    
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
        for index in offsets {
            let item = materials[index]
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
