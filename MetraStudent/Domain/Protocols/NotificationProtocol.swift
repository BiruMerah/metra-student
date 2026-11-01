//
//  NotificationProtocol.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 01/11/26.
//

import Foundation

@MainActor
protocol NotificationProtocol: AnyObject {
    func requestAuthorizationIfNeeded() async
    
    func notifyNewMaterials(_ materials: [MathMaterialModel], classroomID: String, classroomName: String)
    
    func announceAccessibility(_ message: String)
}
