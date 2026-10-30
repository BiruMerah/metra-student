//
//  ClassroomNetworkContract.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 30/10/26.
//

import Foundation

nonisolated struct BroadcastPayload: Codable, Equatable, Sendable {
    let classroomName: String
    let teacherName: String
    let materials: [MathMaterialModel]
    
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
