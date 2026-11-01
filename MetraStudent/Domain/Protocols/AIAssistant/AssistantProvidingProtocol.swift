//
//  AssistantProvidingProtocol.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 01/11/26.
//

import Foundation

@MainActor
protocol AssistantProvidingProtocol {
    var availabilityMessage: String? { get }
    
    func result(
        action: AIAssistantAction,
        selection: AIAssistantSelection,
        progress: @escaping @MainActor (AIAssistantProgress) -> Void
    ) async throws -> AIAssistantResult
    
    func cancel()
}
