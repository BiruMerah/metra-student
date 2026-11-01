//
//  ClassroomNetworkContract.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 30/10/26.
//

import Foundation

nonisolated struct MathMaterialDTO: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let category: String
    let content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        category: String = "Tester",
        content: String = "Tester",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.content = content
        self.createdAt = createdAt
    }

    init(from domain: MathMaterialModel) {
        self.id = domain.id
        self.title = domain.title
        self.category = domain.category
        self.content = domain.content
        self.createdAt = domain.createdAt
    }

    func toDomain() -> MathMaterialModel {
        MathMaterialModel(
            id: id,
            title: title,
            category: category,
            content: content,
            createdAt: createdAt
        )
    }
}

nonisolated struct BroadcastPayload: Codable, Equatable, Sendable {
    let classroomName: String
    let teacherName: String
    let materials: [MathMaterialDTO]
    
    enum CodingKeys: String, CodingKey {
        case classroomName = "roomName"
        case teacherName
        case materials
    }
}

nonisolated enum ClassroomNetworkMessage: Codable, Equatable, Sendable {
    case studentInformation(id: String, name: String)
    case classroomSync(BroadcastPayload)
    
    enum CodingKeys: String, CodingKey {
        case studentInformation = "studentHello"
        case classroomSync = "roomSync"
    }
}
