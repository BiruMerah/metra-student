//
//  MathMaterialProtocol.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

@MainActor
protocol MathMaterialProtocol {
    func fetchSavedMaterials() throws -> [MathMaterialModel]
    
    func evaluateSaveStatus(for material: MathMaterialModel) throws -> MaterialSaveStatus
    
    func saveMaterial(_ material: MathMaterialModel) throws
    
    func deleteMaterial(id: UUID) throws
    
    func overview(for material: MathMaterialModel) -> MaterialOverview
    
    func topics(for material: MathMaterialModel) -> [MathTopicModel]
}

nonisolated struct MaterialSaveStatus: Equatable, Sendable {
    let isSaved: Bool
    let hasDuplicateTitle: Bool

    var canSave: Bool {
        !isSaved && !hasDuplicateTitle
    }
}
