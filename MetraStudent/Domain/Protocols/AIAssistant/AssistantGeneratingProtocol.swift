import Foundation

@MainActor
protocol AssistantGeneratingProtocol {
    var availabilityMessage: String? { get }
    var availabilityCanOpenSettings: Bool { get }
    func respond(instructions: String, prompt: String) async throws -> String
}

extension AssistantGeneratingProtocol {
    var availabilityCanOpenSettings: Bool { false }
}
