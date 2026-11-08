import Foundation
#if os(iOS)
import MetraDocumentPipeline
#endif

@MainActor
enum StudentDocumentConverter {
    static var isSupported: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    static func convert(_ url: URL, onProgress: @escaping @MainActor (String) -> Void) async throws -> MathMaterialModel {
        #if os(iOS)
        let payload = try await DocumentPipeline.convert(url, onProgress: onProgress)
        return try JSONDecoder().decode(PortableMaterial.self, from: payload).studentMaterial
        #else
        throw UnsupportedPlatform()
        #endif
    }

    static func convertPhoto(
        _ data: Data, title: String, onProgress: @escaping @MainActor (String) -> Void
    ) async throws -> MathMaterialModel {
        #if os(iOS)
        let payload = try await DocumentPipeline.convertPhoto(data, title: title, onProgress: onProgress)
        return try JSONDecoder().decode(PortableMaterial.self, from: payload).studentMaterial
        #else
        throw UnsupportedPlatform()
        #endif
    }

    private struct UnsupportedPlatform: LocalizedError {
        var errorDescription: String? { "Impor dokumen tersedia di iPhone dan iPad." }
    }

    // The portable material stores the ordered reading chunks. The student's
    // separate content array is used for older materials without those chunks.
    private struct PortableMaterial: Decodable {
        struct Topic: Decodable {
            let id: UUID
            let title: String
            let chunks: [MetraChunk]
        }

        let id: UUID
        let title: String
        let category: String
        let content: String
        let createdAt: Date
        let overview: String?
        let topics: [Topic]

        var studentMaterial: MathMaterialModel {
            MathMaterialModel(
                id: id,
                title: title,
                category: category,
                content: content,
                createdAt: createdAt,
                overview: overview,
                topics: topics.map { MathTopicModel(id: $0.id, title: $0.title, chunks: $0.chunks) }
            )
        }
    }
}
