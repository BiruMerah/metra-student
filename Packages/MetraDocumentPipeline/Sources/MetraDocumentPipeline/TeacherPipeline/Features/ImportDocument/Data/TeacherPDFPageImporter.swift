#if os(iOS)
import Foundation
import PDFKit
import UIKit

/// Reads the complete PDF before returning any pages, so a failed import never
/// leaves a partially appended document in the preparation screen.
nonisolated enum TeacherPDFPageImporter {
    static let pageLimit = 10

    static func read(from url: URL, remainingPages: Int) throws -> [MaterialImageInput] {
        guard url.pathExtension.lowercased() == "pdf" else {
            throw ImportError.invalid("Unggah PDF hanya menerima berkas PDF.")
        }
        guard remainingPages > 0 else {
            throw ImportError.invalid("Maksimal 10 halaman per dokumen.")
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        var readError: NSError?
        var result: Result<[MaterialImageInput], Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &readError) { safeURL in
            result = Result {
                let size = try safeURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 50 * 1_024 * 1_024 else {
                    throw ImportError.invalid("Pilih PDF berukuran maksimal 50 MB.")
                }
                let data = try Data(contentsOf: safeURL)
                guard let document = PDFDocument(data: data), !document.isLocked, document.pageCount > 0 else {
                    throw ImportError.invalid("PDF tidak dapat dibaca atau terkunci.")
                }
                let capacity = min(pageLimit, remainingPages)
                guard document.pageCount <= capacity else {
                    throw ImportError.invalid("PDF ini memiliki \(document.pageCount) halaman. Sisa kapasitas \(capacity) halaman; maksimal 10 halaman per dokumen.")
                }
                return try (0..<document.pageCount).map { index in
                    try Task.checkCancellation()
                    return try autoreleasepool {
                        guard let page = document.page(at: index) else { throw CocoaError(.fileReadCorruptFile) }
                        let bounds = page.bounds(for: .mediaBox)
                        guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else {
                            throw CocoaError(.fileReadCorruptFile)
                        }
                        let scale = min(2_400 / max(bounds.width, bounds.height), 3)
                        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                        let image = page.thumbnail(of: size, for: .mediaBox)
                        guard let bytes = image.jpegData(compressionQuality: 0.95) else { throw CocoaError(.fileReadCorruptFile) }
                        return MaterialImageInput(data: bytes,
                            fileName: "\(url.deletingPathExtension().lastPathComponent)-\(index + 1).jpg", origin: .files)
                    }
                }
            }
        }
        if let readError { throw readError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    enum ImportError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { switch self { case .invalid(let message): message } }
    }
}

extension TeacherPDFPageImporter.ImportError: TeacherUserFacingError { }

#endif
