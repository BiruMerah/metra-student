#if os(iOS)
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Local document conversion. The returned payload follows Teacher's portable material
/// schema, but is a personal draft rather than a teacher-validated export.
@MainActor
public enum DocumentPipeline {
    private static var isConverting = false
    public static func convert(
        _ url: URL, onProgress: @escaping @MainActor (String) -> Void
    ) async throws -> Data {
        try await convert(
            title: url.deletingPathExtension().lastPathComponent,
            preparesImage: url.pathExtension.lowercased() != "pdf",
            onProgress: onProgress
        ) {
            onProgress("Membuka dokumen…")
            let reader = Task.detached(priority: .userInitiated) { try readPages(from: url) }
            return try await withTaskCancellationHandler {
                try await reader.value
            } onCancel: {
                reader.cancel()
            }
        }
    }

    public static func convertPhoto(
        _ data: Data, title: String, fromCamera: Bool = false, onProgress: @escaping @MainActor (String) -> Void
    ) async throws -> Data {
        try await convert(title: title, preparesImage: true, onProgress: onProgress) {
            [try readImage(data, origin: fromCamera ? .camera : .photoLibrary)]
        }
    }

    private static func convert(
        title: String,
        preparesImage: Bool,
        onProgress: @escaping @MainActor (String) -> Void,
        loadInputs: () async throws -> [MaterialImageInput]
    ) async throws -> Data {
        guard !isConverting else { throw ExtractionServiceError.busy }
        isConverting = true
        let workspace = ImageIngestor.conversionDirectory
        defer {
            try? FileManager.default.removeItem(at: workspace)
            isConverting = false
        }
        do {
            if FileManager.default.fileExists(atPath: workspace.path) {
                try FileManager.default.removeItem(at: workspace)
            }
            let inputs = try await loadInputs()
            try Task.checkCancellation()
            let pages: [MaterialImageInput]
            if preparesImage {
                onProgress("Menyiapkan gambar…")
                pages = try await VisionDocumentImagePreparer().prepare(inputs, remainingPages: TeacherPDFPageImporter.pageLimit)
            } else {
                pages = inputs
            }
            try Task.checkCancellation()

            let stem = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let materialTitle = stem.isEmpty ? "Materi baru" : String(stem.prefix(120))
            let extraction = TeacherMaterialExtractionService()
            let result: TeacherExtractionResult
            do {
                result = try await extraction.extract(pages: pages, title: materialTitle, firstBookPage: nil,
                                                      onProgress: onProgress)
            } catch let recovery as TeacherConversionRecovery {
                let failed = Set(recovery.assessments.filter { $0.status != .ready }.map(\.id))
                let numbers = pages.enumerated().compactMap { failed.contains($0.element.id) ? String($0.offset + 1) : nil }
                throw ImportError.invalid(numbers.isEmpty
                    ? "Dokumen tidak menghasilkan bacaan. Coba gunakan dokumen yang lebih jelas."
                    : "Halaman \(numbers.joined(separator: ", ")) belum bisa dibaca. Periksa halaman tersebut dan coba lagi.")
            }
            try Task.checkCancellation()
            var material = result.material
            material.reviewStatus = .draft
            material.validatedAt = nil
            return try JSONEncoder().encode(material)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as TeacherUserFacingError {
            throw error
        } catch {
            throw ImportError.invalid("Dokumen belum bisa dikonversi. Periksa apakah berkas bisa dibuka, lalu coba lagi.")
        }
    }

    private nonisolated static func readPages(from url: URL) throws -> [MaterialImageInput] {
        if url.pathExtension.lowercased() == "pdf" {
            return try TeacherPDFPageImporter.read(from: url, remainingPages: TeacherPDFPageImporter.pageLimit)
        }

        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<MaterialImageInput, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { safeURL in
            result = Result {
                try Task.checkCancellation()
                let size = try safeURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 50 * 1_024 * 1_024 else {
                    throw ImportError.invalid("Pilih gambar berukuran maksimal 50 MB.")
                }
                return try readImage(Data(contentsOf: safeURL), fileName: url.lastPathComponent, origin: .files)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return [try result.get()]
    }

    private nonisolated static func readImage(
        _ data: Data, fileName: String? = nil, origin: MaterialImageInput.Origin
    ) throws -> MaterialImageInput {
        try Task.checkCancellation()
        guard data.count <= 50 * 1_024 * 1_024 else {
            throw ImportError.invalid("Pilih gambar berukuran maksimal 50 MB.")
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source),
              let imageType = UTType(type as String), imageType.conforms(to: .image),
              CGImageSourceGetCount(source) == 1,
              let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = info[kCGImagePropertyPixelWidth] as? Double,
              let height = info[kCGImagePropertyPixelHeight] as? Double,
              width > 0, height > 0, width * height <= 64_000_000 else {
            throw ImportError.invalid("Pilih gambar satu halaman yang bisa dibaca, misalnya JPEG, PNG, atau HEIC hingga 64 megapiksel.")
        }
        let name = fileName ?? "foto.\(imageType.preferredFilenameExtension ?? "image")"
        return .init(data: data, fileName: name, origin: origin)
    }

    private enum ImportError: TeacherUserFacingError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let message): message }
        }
    }
}
#endif
