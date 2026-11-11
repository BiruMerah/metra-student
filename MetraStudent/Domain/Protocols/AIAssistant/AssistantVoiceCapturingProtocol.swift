import Foundation

@MainActor
protocol AssistantVoiceCapturingProtocol {
    func requestPermissions() async throws
    func start(localeIdentifier: String) throws
    func finish() async throws -> String
    func cancel()
}
