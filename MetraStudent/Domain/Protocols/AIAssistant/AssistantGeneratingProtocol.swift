import Foundation

@MainActor
protocol AssistantGeneratingProtocol {
    var availabilityMessage: String? { get }
    func respond(instructions: String, prompt: String) async throws -> String
}
