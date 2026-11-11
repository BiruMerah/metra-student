import Foundation

nonisolated struct AIAssistantSelection: Identifiable, Equatable {
    let id: String
    let sentence: String
    let topicTitle: String
    let materialTitle: String
    let supportingText: String
}

nonisolated enum AIAssistantFailure: LocalizedError {
    case message(String)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .message(let message), .permissionDenied(let message): message
        }
    }
}
