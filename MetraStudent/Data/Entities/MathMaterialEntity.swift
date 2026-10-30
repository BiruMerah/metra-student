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
    
    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
    
    // MARK: - Mapper
    func toDomain() -> MathMaterialModel {
        MathMaterialModel(
            id: self.id,
            title: self.title,
            category: "Tester",
            content: "Tester Content",
            createdAt: .now
        )
    }
    
    static func from(domain: MathMaterialModel) -> MathMaterialEntity {
        MathMaterialEntity(
            id: domain.id,
            title: domain.title
        )
    }
}
