//
//  DiscoveredClassroom.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

// Domain model for Network Connection
struct DiscoveredClassroom: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let classroomName: String
    let teacherName: String
    
    init(id: String = UUID().uuidString, classroomName: String, teacherName: String) {
        self.id = id
        self.classroomName = classroomName
        self.teacherName = teacherName
    }
}

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
