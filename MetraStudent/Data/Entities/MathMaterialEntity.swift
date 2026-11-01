//
//  MathMaterialEntity.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation
import SwiftData

@Model
final class MathMaterialEntity {
    @Attribute(.unique)
    var id: UUID
    
    var title: String
    var category: String = ""
    var content: String = ""
    var createdAt: Date = Date.now
    
    init(
        id: UUID = UUID(),
        title: String,
        category: String = "",
        content: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.content = content
        self.createdAt = createdAt
    }
    
    // MARK: - Mapper
    func toDomain() -> MathMaterialModel {
        MathMaterialModel(
            id: self.id,
            title: self.title,
            category: self.category,
            content: self.content,
            createdAt: self.createdAt
        )
    }
    
    static func from(domain: MathMaterialModel) -> MathMaterialEntity {
        MathMaterialEntity(
            id: domain.id,
            title: domain.title,
            category: domain.category,
            content: domain.content,
            createdAt: domain.createdAt
        )
    }
}
