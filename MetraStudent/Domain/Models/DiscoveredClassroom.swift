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
    let id: String
    let endpoint: Bonjour.Endpoint?
    let classroomName: String
    let teacherName: String
    
    init(id: String = UUID().uuidString, endpoint: Bonjour.Endpoint? = nil, classroomName: String, teacherName: String) {
        self.id = id
        self.endpoint = endpoint
        self.classroomName = classroomName
        self.teacherName = teacherName
    }
}

#if DEBUG
extension DiscoveredClassroom {
    static let sample = DiscoveredClassroom(
        classroomName: "Kelas 4A - Matematika",
        teacherName: "Bpk. Budi Santoso"
    )
    
    static let sampleConnecting = DiscoveredClassroom(
        classroomName: "Kelas 5B - Bahasa Indonesia",
        teacherName: "Ibu Siti Rahma"
    )
    
    static let sampleConnected = DiscoveredClassroom(
        classroomName: "Kelas 6C - Ilmu Pengetahuan Alam",
        teacherName: "Bpk. Joko Anwar"
    )
}
#endif
