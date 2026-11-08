#if os(iOS)
import Foundation

/// Generation metadata stays in the teacher run; only the editable text travels
/// in the portable material. The summary describes the entire file, not a topic.
nonisolated struct MaterialOverviewResult: Codable, Equatable, Sendable {
    var schema = "metra-material-overview-v1"
    let text: String
    let provider: String
    let status: String
    let sourceTopicIDs: [UUID]
    let sourceChunkCount: Int
    let reason: String?
}

protocol MaterialOverviewGenerating: Sendable {
    func generate(for material: StudyMaterial) async throws -> MaterialOverviewResult
}

protocol OverviewTextSummarizing: Sendable {
    func summarize(_ source: String) async throws -> String
}

nonisolated struct MaterialOverviewUnavailable: Error, Sendable {
    let reason: String
}

#endif
