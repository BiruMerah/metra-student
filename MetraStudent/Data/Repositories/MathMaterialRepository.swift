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
        let targetId = material.id
        let predicate = #Predicate<MathMaterialEntity> { $0.id == targetId }
        let descriptor = FetchDescriptor<MathMaterialEntity>(predicate: predicate)
        
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                existing.update(from: material)
            } else {
                let entity = MathMaterialEntity.from(domain: material)
                modelContext.insert(entity)
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
    
    func deleteMaterials(ids: Set<UUID>) throws {
        guard !ids.isEmpty else { return }
        let targetIDs = Array(ids)
        let descriptor = FetchDescriptor<MathMaterialEntity>(
            predicate: #Predicate { targetIDs.contains($0.id) }
        )
        do {
            let entities = try modelContext.fetch(descriptor)
            for entity in entities {
                modelContext.delete(entity)
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func overview(for material: MathMaterialModel) -> MaterialOverview {
        return material.materialOverview
    }
    
    func topics(for material: MathMaterialModel) -> [MathTopicModel] {
        if !material.topics.isEmpty {
            return material.topics
        }
        let trimmed = material.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return [MathTopicModel(title: material.title, content: [.text(trimmed)])]
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
    
    func deleteMaterials(ids: Set<UUID>) throws {
        materials.removeAll { ids.contains($0.id) }
    }
    
    func overview(for material: MathMaterialModel) -> MaterialOverview {
        return material.materialOverview
    }
    
    func topics(for material: MathMaterialModel) -> [MathTopicModel] {
        if !material.topics.isEmpty {
            return material.topics
        }
        let trimmed = material.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return [MathTopicModel(title: material.title, content: [.text(trimmed)])]
    }
}
