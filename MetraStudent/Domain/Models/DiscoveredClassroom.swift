//
//  DiscoveredClassroom.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation
import Network

// Domain model for Network Connection
struct DiscoveredClassroom: Identifiable, Equatable, Sendable {
    let endpoint: Bonjour.Endpoint
    let classroomName: String
    let teacherName: String
    
    var id: String {
        endpoint.id
    }
}
