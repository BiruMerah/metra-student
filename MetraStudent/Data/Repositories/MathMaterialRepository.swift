//
//  MathMaterialRepository.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation
import SwiftData

final class MathMaterialRepository: MathMaterialProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Protocol implementation
    func fetchSavedMaterials() throws -> [MathMaterialModel] {
        let descriptor = FetchDescriptor<MathMaterialEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        
        return entities.map { $0.toDomain() }
    }
    
    func evaluateSaveStatus(for material: MathMaterialModel) throws -> MaterialSaveStatus {
        let savedMaterials = try fetchSavedMaterials()
        let isSaved = savedMaterials.contains { $0.id == material.id }
        let normalizedTitle = material.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let hasDuplicateTitle = savedMaterials.contains {
            $0.id != material.id &&
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle
        }
        
        return MaterialSaveStatus(isSaved: isSaved, hasDuplicateTitle: hasDuplicateTitle)
    }
    
    func saveMaterial(_ material: MathMaterialModel) throws {
        let entity = MathMaterialEntity.from(domain: material)
        modelContext.insert(entity)
        try modelContext.save()
    }
    
    func deleteMaterial(id: UUID) throws {
        let targetId = id
        let predicate = #Predicate<MathMaterialEntity> { $0.id == targetId }
        let descriptor = FetchDescriptor<MathMaterialEntity>(predicate: predicate)
        
        if let entity = try modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try modelContext.save()
        }
    }
    
    func overview(for material: MathMaterialModel) -> MaterialOverview {
        return MaterialOverview.sample
    }
    
    func topics(for material: MathMaterialModel) -> [MathTopicModel] {
        return MathTopicModel.sampleTopics
    }
}


//
final class InMemoryMathMaterialRepository: MathMaterialProtocol {
    private var materials: [MathMaterialModel]
    
    init(materials: [MathMaterialModel] = []) {
        self.materials = materials
    }
    
    func fetchSavedMaterials() throws -> [MathMaterialModel] {
        materials.sorted { $0.createdAt > $1.createdAt }
    }
    
    func addSavedMaterial(material: MathMaterialModel) throws {
        materials.removeAll { $0.id == material.id }
        materials.append(material)
    }
    
    func deleteSavedMaterial(id: UUID) throws {
        materials.removeAll { $0.id == id }
    }
    
    func evaluateSaveStatus(for material: MathMaterialModel) throws -> MaterialSaveStatus {
        let isSaved = materials.contains { $0.id == material.id }
        let normalizedTitle = material.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let hasDuplicateTitle = materials.contains {
            $0.id != material.id &&
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle
        }
        return MaterialSaveStatus(isSaved: isSaved, hasDuplicateTitle: hasDuplicateTitle)
    }
    
    func saveMaterial(_ material: MathMaterialModel) throws {
        // Reuses your existing addSavedMaterial logic
        try addSavedMaterial(material: material)
    }
    
    func deleteMaterial(id: UUID) throws {
        // Reuses your existing deleteSavedMaterial logic
        try deleteSavedMaterial(id: id)
    }
    
    func overview(for material: MathMaterialModel) -> MaterialOverview {
        // Assuming MathMaterialModel contains an 'overview' property
        return MaterialOverview.sample
    }
    
    func topics(for material: MathMaterialModel) -> [MathTopicModel] {
        // Assuming MathMaterialModel contains a 'topics' array
        return MathTopicModel.sampleTopics
    }
}
