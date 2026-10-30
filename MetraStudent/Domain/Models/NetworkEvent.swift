//
//  NetworkEvent.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 30/10/26.
//

import Foundation

enum NetworkEvent: Sendable {
    case searchingChanged(Bool)
    case searchFailed(String)
    case classroomUpdated([DiscoveredClassroom])
    case classroomConnecting(DiscoveredClassroom)
    case classroomConnected(DiscoveredClassroom)
    case classroomSynced(classroomId: String, classroomName: String, teacherName: String, materials: [MathMaterialModel])
    case classroomDisconnected(classroomId: String)
    case leftClassroom
    case resetAll
}
