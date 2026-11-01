//
//  AssistantGeneratingProtocol.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 01/11/26.
//

import Foundation

@MainActor
protocol AssistantGeneratingProtocol {
    var availabilityMessage: String? { get }
    
    var outputLanguage: String { get }
    
    func generate(action: MetraAssistantAction, sentences: [String], extraBrief: Bool) async throws -> [String]
}
