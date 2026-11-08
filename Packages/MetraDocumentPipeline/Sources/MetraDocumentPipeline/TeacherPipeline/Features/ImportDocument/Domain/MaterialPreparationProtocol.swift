#if os(iOS)
import Foundation

/// Application-facing AI boundary for page checks and material conversion.
@MainActor
protocol MaterialPreparationProtocol {
    var modelStatus: String { get }
    func inspect(pages: [MaterialImageInput], retry: Bool,
        onAssessment: @escaping @MainActor (TeacherPageAssessment) -> Void,
        onProgress: @escaping @MainActor (String) -> Void) async throws -> [TeacherPageAssessment]
    func extract(pages: [MaterialImageInput], title: String, firstBookPage: Int?,
        bookPageLabels: [Int]?, uncertainPageIDs: Set<UUID>,
        onProgress: @escaping @MainActor (String) -> Void) async throws -> TeacherExtractionResult
    func cancel()
}

extension MaterialPreparationProtocol {
    func extract(pages: [MaterialImageInput], title: String, firstBookPage: Int?,
                 onProgress: @escaping @MainActor (String) -> Void) async throws -> TeacherExtractionResult {
        try await extract(pages: pages, title: title, firstBookPage: firstBookPage,
            bookPageLabels: nil, uncertainPageIDs: [], onProgress: onProgress)
    }
}

#endif
