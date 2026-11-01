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
        action: MetraAssistantAction,
        selection: MetraAssistantSelection,
        progress: @escaping @MainActor (MetraAssistantProgress) -> Void
    ) async throws -> MetraAssistantResult
    
    func cancel()
}
