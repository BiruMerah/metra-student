//
//  AppTab.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 30/10/26.
//

import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case classroom
    case library
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .classroom:
            return "Ruang Kelas"
            
        case .library:
            return "Pustaka"
        }
    }
    
    var iconName: String {
        switch self {
        case .classroom:
            return "graduationcap.fill"
            
        case .library:
            return "books.vertical.fill"
        }
    }
}
