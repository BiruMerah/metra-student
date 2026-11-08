#if os(iOS)
import Foundation

/// Advisory input checks, not a document classifier or a guarantee of OCR accuracy.
nonisolated enum TeacherPageReadability {
    static func issueSummary(issueIDs: Set<UUID>, orderedIDs: [UUID]) -> String {
        let numbers = orderedIDs.enumerated().compactMap { issueIDs.contains($0.element) ? $0.offset + 1 : nil }
        let locations = numbers.map(String.init).joined(separator: ", ")
        return "\(numbers.count) dari \(orderedIDs.count) halaman perlu diperiksa (halaman \(locations))"
    }

    struct Evidence: Sendable {
        var ocrSucceeded = true
        var layoutSucceeded = true
        var characters = 0
        var confidentCharacters = 0
        var textAreaFraction = 0.0
        var hasTextLayout = false
        var hasFormulaOrTable = false
        var hasSupportedVisual = false
        var hasUncertainVisual = false
        var ordinaryPhotoDominates = false
    }

    /// Initial, conservative heuristics. Low evidence asks the teacher; it never
    /// asserts that a photo is unrelated to the intended lesson.
    static func assess(_ evidence: Evidence, id: UUID) -> TeacherPageAssessment {
        if !evidence.ocrSucceeded || !evidence.layoutSucceeded {
            return .init(id: id, status: .processingFailed,
                message: "Pemeriksaan halaman belum berhasil. Coba lagi atau ganti gambar. Ini belum berarti gambar tidak berisi materi.")
        }
        // Layout and visual labels propose a route; they do not prove that
        // content was read. In particular, a photograph can be misclassified
        // as a formula/table/diagram. Never auto-pass a zero-OCR image.
        if evidence.characters == 0 {
            if !evidence.ordinaryPhotoDominates && (evidence.hasFormulaOrTable || evidence.hasSupportedVisual) {
                return .init(id: id, status: .needsAttention,
                    message: "Teks belum terdeteksi pada gambar ini. Jika ini memang rumus, tabel, atau diagram materi, periksa gambarnya lalu pilih Tetap lanjutkan. Hasilnya tetap wajib diperiksa sebelum disimpan atau dibagikan.")
            }
            return .init(id: id, status: .unreadable,
                message: "Kami belum menemukan teks, rumus, atau diagram yang dapat dibaca. Gunakan foto materi yang lebih dekat, jelas, dan terang.")
        }
        // A few hallucinated OCR characters must not be rescued by a visual
        // prediction either. Sparse or weak readings always require review.
        if evidence.characters < 24 || evidence.confidentCharacters < 12 || evidence.hasUncertainVisual
            || (evidence.ordinaryPhotoDominates && evidence.textAreaFraction < 0.18) {
            return .init(id: id, status: .needsAttention,
                message: "Isi yang dapat dibaca masih terbatas atau gambar belum jelas sebagai materi. Periksa gambar, lalu ganti atau lanjutkan jika sudah sesuai.")
        }
        return .init(id: id, status: .ready, message: "")
    }

    /// A page with unresolved formulas/diagrams still has reviewable content.
    /// Only pages with no body chunks are recovery candidates after conversion.
    static func afterConversion(id: UUID, hasBodyChunks: Bool, processingSucceeded: Bool) -> TeacherPageAssessment {
        if !processingSucceeded {
            return .init(id: id, status: .processingFailed, stage: .conversion,
                message: "Pemrosesan halaman belum berhasil. Coba lagi atau ganti gambar. Halaman sumber tetap tersedia.")
        }
        return .init(id: id, status: hasBodyChunks ? .ready : .unreadable, stage: .conversion,
            message: hasBodyChunks ? "" : "Konversi belum menghasilkan bacaan dari halaman ini. Ganti gambar atau hapus halaman untuk melanjutkan.")
    }
}

#endif
