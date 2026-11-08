//
//  AppTab.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 30/10/26.
//

import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case channel
    case document
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .channel:
            return "Channel"
            
        case .document:
            return "Dokumen"
        }
    }
    
    var iconName: String {
        switch self {
        case .channel:
            return "bubble.left.and.bubble.right"
            
        case .document:
            return "doc.text"
        }
    }
}
