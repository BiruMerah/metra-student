import Foundation

@MainActor
protocol MetraAssistantTranslating {
    func translate(_ texts: [String], from source: String, to target: String) async throws -> [String]
    func cancel()
}

@MainActor
protocol MetraAssistantGenerating {
    var availabilityMessage: String? { get }
    var outputLanguage: String { get }
    func generate(action: MetraAssistantAction, sentences: [String], extraBrief: Bool) async throws -> [String]
}

@MainActor
protocol MetraAssistantProviding {
    var availabilityMessage: String? { get }
    func result(
        action: MetraAssistantAction,
        selection: MetraAssistantSelection,
        progress: @escaping @MainActor (MetraAssistantProgress) -> Void
    ) async throws -> MetraAssistantResult
    func cancel()
}
