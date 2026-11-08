import Foundation

@MainActor
protocol MetraAssistantGenerating {
    var availabilityMessage: String? { get }
    func respond(instructions: String, prompt: String) async throws -> String
}

@MainActor
protocol MetraVoiceCapturing {
    func requestPermissions() async throws
    func start(localeIdentifier: String) throws
    func finish() async throws -> String
    func cancel()
}
