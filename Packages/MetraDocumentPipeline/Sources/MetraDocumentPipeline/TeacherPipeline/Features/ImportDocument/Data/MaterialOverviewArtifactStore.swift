#if os(iOS)
import Foundation

/// Retains the whole-file overview beside the exact OCR/formula artifacts.
/// preview_material.json is a draft, never a validated .metra export.
struct MaterialOverviewArtifactStore {
    func write(_ overview: MaterialOverviewResult, material: StudyMaterial, to root: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let readyURL = root.appendingPathComponent("final_ready.json")
        guard var ready = try JSONSerialization.jsonObject(with: Data(contentsOf: readyURL)) as? [String: Any],
              let id = ready["id"] as? String, id.lowercased() == material.id.uuidString.lowercased() else {
            throw MetraMaterialError.invalidContent
        }
        ready["overview"] = overview.text
        ready["overviewArtifact"] = "overview.json"
        try encoder.encode(overview).write(to: root.appendingPathComponent("overview.json"), options: .atomic)
        try encoder.encode(material).write(to: root.appendingPathComponent("preview_material.json"), options: .atomic)
        try JSONSerialization.data(withJSONObject: ready, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            .write(to: readyURL, options: .atomic)
    }
}

#endif
