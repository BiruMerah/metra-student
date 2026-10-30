//
//  MathMaterialModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

// Domain model (don't implement pk)
nonisolated struct MathMaterialModel: Identifiable, Codable, Equatable, Hashable, Sendable {
    // TODO: Define list of model properties
    let id: UUID
    var title: String
    var category: String
    var content: String
    var createdAt: Date = Date()
    
    init(id: UUID = UUID(), title: String, category: String = "Tester", content: String = "Tester", createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.category = category
        self.content = content
        self.createdAt = createdAt
    }
}
