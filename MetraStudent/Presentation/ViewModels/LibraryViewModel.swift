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
    var errorMessage: String?
    var isLoading: Bool = false
    
    // MARK: - Dependencies
    private let mathMaterialRepository: MathMaterialProtocol
    
    init(mathMaterialRepository: MathMaterialProtocol) {
        self.mathMaterialRepository = mathMaterialRepository
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
    
    func addSavedMaterial() {
        let newMaterial = MathMaterialModel(title: "Math Topic #\(materials.count + 1)")
        do {
            try mathMaterialRepository.addSavedMaterial(material: newMaterial)
            loadMaterials() // Refresh list
        } catch {
            self.errorMessage = error.localizedDescription
        }
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
}
