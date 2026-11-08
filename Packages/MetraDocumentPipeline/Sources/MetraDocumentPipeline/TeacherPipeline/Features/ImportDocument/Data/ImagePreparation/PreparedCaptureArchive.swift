#if os(iOS)
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Local provenance only. Neither the original capture nor its path is sent in .metra.
nonisolated enum PreparedCaptureArchive {
    static func record(_ preparation: DocumentImagePreparation, for source: ImportedSourcePage) throws {
        let documents = try ImageIngestor.documentsURL()
        let relative = "metra-inputs/captures/\(preparation.sourceID.uuidString.lowercased())"
        let root = documents.appendingPathComponent(relative, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let uti = CGImageSourceCreateWithData(preparation.originalData as CFData, nil).flatMap { CGImageSourceGetType($0) }
        let ext = uti.flatMap { UTType($0 as String)?.preferredFilenameExtension } ?? "image"
        let original = root.appendingPathComponent("original.\(ext)")
        if !FileManager.default.fileExists(atPath: original.path) { try preparation.originalData.write(to: original, options: .atomic) }
        var record: [String: Any] = ["schema": "metra-image-preparation-v1", "source_id": preparation.sourceID.uuidString,
            "original_relative_path": relative + "/" + original.lastPathComponent,
            "original_sha256": ImageIngestor.sha256(preparation.originalData),
            "page_number": preparation.pageNumber, "page_count": preparation.pageCount,
            "coordinate_origin": "bottom_left_upright_normalized"]
        if let boundary = preparation.boundary { record["boundary"] = boundary.points.map { [Double($0.x), Double($0.y)] } }
        let data = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: documents.appendingPathComponent(source.relativeDirectory).appendingPathComponent("preparation.json"), options: .atomic)
    }
}

#endif
