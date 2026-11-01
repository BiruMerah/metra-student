//
//  AssistantTranslatingProtocol.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 01/11/26.
//

import Foundation

@MainActor
protocol AssistantTranslatingProtocol {
    func translate(_ texts: [String], from source: String, to target: String) async throws -> [String]
    
    func cancel()
}
