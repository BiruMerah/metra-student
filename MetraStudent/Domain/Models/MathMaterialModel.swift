//
//  MathMaterialModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

nonisolated struct MaterialOverview: Equatable, Hashable, Sendable {
    let chapter: String
    let subchapter: String
    let pageNumber: Int
    let questionCount: Int

    static let sample = MaterialOverview(
        chapter: "Bab I - Persamaan Linear Satu Variabel",
        subchapter: "Mengenal dan Menyelesaikan Persamaan Linear",
        pageNumber: 21,
        questionCount: 1
    )
}

nonisolated struct MathMaterialModel: Identifiable, Codable, Equatable, Hashable, Sendable {
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
