#if os(iOS)
import Foundation

// Portable wire/file contract: retain Codable compatibility with StudentPeerPOC.
// No source images, local paths, or extraction models belong in this document.
nonisolated enum MetraSpeechStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case clearSpeak, simpleSpeak

    var id: Self { self }
    var label: String { self == .clearSpeak ? "ClearSpeak" : "SimpleSpeak" }
}

nonisolated enum MetraReviewStatus: String, Codable, Sendable {
    case draft, validated
}

nonisolated struct MetraContentPart: Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable { case text, math }
    var kind: Kind
    var text: String?
    var mathML: String?
    var clearSpeak: String?
    var simpleSpeak: String?
    /// Additive fields: old Student clients ignore these and keep their two styles.
    var speakEasy: String? = nil
    var speakEasyFallbackTags: [String]? = nil
    var speakEasyError: String? = nil

    static func prose(_ text: String) -> Self { .init(kind: .text, text: text) }

    func readingText(style: MetraSpeechStyle) -> String {
        switch kind {
        case .text: return text ?? ""
        case .math: return (style == .clearSpeak ? clearSpeak : simpleSpeak) ?? ""
        }
    }
}

nonisolated struct MetraChunk: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID = UUID()
    var pageLabel: String?
    var parts: [MetraContentPart]
    /// A teacher's correction always takes priority over either generated style.
    var teacherSpokenOverride: String?
    var requiresTeacherCorrection: Bool? = nil
    var reviewNote: String? = nil
    var sourceChunkIDs: [String]? = nil
    /// Source representation retained when a teacher splits a corrected reading.
    var originalParts: [MetraContentPart]? = nil

    /// Only expose a complete variant; never present mixed/missing speech as SpeakEasy.
    var speakEasyReadingText: String? {
        guard parts.contains(where: { $0.kind == .math }) else { return nil }
        if let correction = teacherSpokenOverride, !correction.isMetraBlank { return correction }
        guard parts.filter({ $0.kind == .math }).allSatisfy({
            $0.speakEasy.map { !$0.isMetraBlank } == true && $0.speakEasyError == nil
        }) else { return nil }
        return parts.map { $0.kind == .text ? ($0.text ?? "") : ($0.speakEasy ?? "") }.joined()
    }

    func readingText(style: MetraSpeechStyle) -> String {
        if let correction = teacherSpokenOverride, !correction.isMetraBlank { return correction }
        return parts.map { $0.readingText(style: style) }.joined()
    }
}

nonisolated struct MetraTopic: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var chunks: [MetraChunk]
}

nonisolated struct StudyMaterial: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var title: String
    var category: String
    var createdAt: Date
    var revision: Int
    var defaultSpeechStyle: MetraSpeechStyle
    var reviewStatus: MetraReviewStatus
    var validatedAt: Date?
    var topics: [MetraTopic]
    /// Whole-file summary; optional so existing v1 documents still decode.
    var overview: String? = nil

    init(id: UUID, title: String, category: String, createdAt: Date, revision: Int,
         defaultSpeechStyle: MetraSpeechStyle, reviewStatus: MetraReviewStatus,
         validatedAt: Date?, topics: [MetraTopic], overview: String? = nil) {
        self.id = id
        self.title = title
        self.category = category
        self.createdAt = createdAt
        self.revision = revision
        self.defaultSpeechStyle = defaultSpeechStyle
        self.reviewStatus = reviewStatus
        self.validatedAt = validatedAt
        self.topics = topics
        self.overview = overview
    }

    var isValidated: Bool { reviewStatus == .validated && validatedAt != nil }
    var content: String {
        ([overview].compactMap { $0 } + topics.flatMap(\.chunks).map { $0.readingText(style: defaultSpeechStyle) }).joined(separator: "\n\n")
    }

    init(id: UUID = UUID(), title: String, category: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.category = category
        self.createdAt = createdAt
        revision = 1
        defaultSpeechStyle = .clearSpeak
        reviewStatus = .draft
        topics = [.init(title: title, chunks: [.init(parts: [.prose(content)])])]
    }

    // Old PoC materials remain local drafts until a teacher reviews them.
    private enum CodingKeys: String, CodingKey {
        case id, title, category, createdAt, revision, defaultSpeechStyle, reviewStatus, validatedAt, topics, content, overview
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        category = try values.decode(String.self, forKey: .category)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        revision = try values.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        defaultSpeechStyle = try values.decodeIfPresent(MetraSpeechStyle.self, forKey: .defaultSpeechStyle) ?? .clearSpeak
        reviewStatus = try values.decodeIfPresent(MetraReviewStatus.self, forKey: .reviewStatus) ?? .draft
        validatedAt = try values.decodeIfPresent(Date.self, forKey: .validatedAt)
        overview = try values.decodeIfPresent(String.self, forKey: .overview)
        if let structured = try values.decodeIfPresent([MetraTopic].self, forKey: .topics) {
            topics = structured
        } else {
            let legacy = try values.decode(String.self, forKey: .content)
            topics = [.init(title: title, chunks: [.init(parts: [.prose(legacy)])])]
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try values.encode(category, forKey: .category)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(revision, forKey: .revision)
        try values.encode(defaultSpeechStyle, forKey: .defaultSpeechStyle)
        try values.encode(reviewStatus, forKey: .reviewStatus)
        try values.encodeIfPresent(validatedAt, forKey: .validatedAt)
        try values.encode(topics, forKey: .topics)
        try values.encodeIfPresent(overview, forKey: .overview)
        // Older PoC receivers can still display the teacher's default reading.
        try values.encode(content, forKey: .content)
    }

    mutating func markValidated() throws {
        try validateStructure()
        guard !isValidated else { return }
        reviewStatus = .validated
        validatedAt = Date()
    }

    /// Use before changing content or the default style; saved student copies keep
    /// their last validated revision while a teacher prepares the next draft.
    mutating func beginRevision() throws {
        if isValidated {
            guard revision < Int.max else { throw MetraMaterialError.invalidContent }
            revision += 1
        }
        reviewStatus = .draft
        validatedAt = nil
    }

    func validateStructure() throws {
        guard revision > 0, !title.isMetraBlank, title.count <= 500,
              !category.isMetraBlank, category.count <= 500,
              !topics.isEmpty, topics.count <= 1_000,
              Set(topics.map(\.id)).count == topics.count else { throw MetraMaterialError.invalidContent }
        guard overview.map({ !$0.isMetraBlank && $0.count <= 8_000 }) ?? true else { throw MetraMaterialError.invalidContent }
        let chunks = topics.flatMap(\.chunks)
        guard !chunks.isEmpty, chunks.count <= 20_000,
              Set(chunks.map(\.id)).count == chunks.count else { throw MetraMaterialError.invalidContent }
        for topic in topics {
            guard !topic.title.isMetraBlank, topic.title.count <= 500, !topic.chunks.isEmpty else {
                throw MetraMaterialError.invalidContent
            }
            for chunk in topic.chunks {
                guard !chunk.parts.isEmpty, chunk.parts.count <= 1_000,
                      chunk.pageLabel.map({ !$0.isMetraBlank && $0.count <= 100 }) ?? true,
                      chunk.teacherSpokenOverride.map({ !$0.isMetraBlank }) ?? true else {
                    throw MetraMaterialError.invalidContent
                }
                if chunk.requiresTeacherCorrection == true && chunk.teacherSpokenOverride == nil {
                    throw MetraMaterialError.correctionRequired
                }
                for part in chunk.parts {
                    switch part.kind {
                    case .text:
                        guard let text = part.text, !text.isEmpty, part.mathML == nil,
                              part.clearSpeak == nil, part.simpleSpeak == nil,
                              part.speakEasy == nil, part.speakEasyFallbackTags == nil, part.speakEasyError == nil else {
                            throw MetraMaterialError.invalidContent
                        }
                    case .math:
                        guard part.text == nil, let mathML = part.mathML, !mathML.isMetraBlank else {
                            throw MetraMaterialError.invalidContent
                        }
                        guard part.speakEasy.map({ !$0.isMetraBlank }) ?? true,
                              part.speakEasyFallbackTags.map({ part.speakEasy != nil && $0.count <= 1_000 && $0.allSatisfy { !$0.isMetraBlank && $0.count <= 200 } }) ?? true,
                              part.speakEasyError.map({ !$0.isMetraBlank && part.speakEasy == nil }) ?? true else {
                            throw MetraMaterialError.invalidContent
                        }
                        // With a manual correction, unresolved generated speech is allowed.
                        if chunk.teacherSpokenOverride == nil {
                            guard let clear = part.clearSpeak, !clear.isMetraBlank,
                                  let simple = part.simpleSpeak, !simple.isMetraBlank else {
                                throw MetraMaterialError.invalidContent
                            }
                        }
                    }
                }
                guard MetraSpeechStyle.allCases.allSatisfy({ !chunk.readingText(style: $0).isMetraBlank }) else {
                    throw MetraMaterialError.invalidContent
                }
            }
        }
        guard (reviewStatus == .validated) == (validatedAt != nil) else { throw MetraMaterialError.invalidContent }
    }

    func validateForSharing() throws {
        try validateStructure()
        guard isValidated else { throw MetraMaterialError.notValidated }
    }
}

nonisolated enum MetraMaterialError: LocalizedError, Equatable {
    case invalidFile, unsupportedVersion, tooLarge, notValidated, invalidContent, conflictingRevision, correctionRequired

    var errorDescription: String? {
        switch self {
        case .invalidFile: return "Berkas bukan materi .metra yang valid atau isinya rusak."
        case .unsupportedVersion: return "Versi berkas .metra ini belum didukung. Perbarui aplikasi."
        case .tooLarge: return "Ukuran materi melebihi batas 8 MB."
        case .notValidated: return "Guru perlu memvalidasi materi sebelum membagikannya."
        case .invalidContent: return "Struktur materi atau teks bacaannya belum lengkap."
        case .conflictingRevision: return "Isi materi berbeda pada nomor revisi yang sama. Minta guru membagikan revisi terbaru."
        case .correctionRequired: return "Ada bagian yang belum dapat dikonversi lengkap. Ubah bacaannya atau hapus bagian tersebut sebelum memvalidasi materi."
        }
    }
}

nonisolated enum MetraMaterialFile {
    static let maximumBytes = 8 * 1_024 * 1_024

    private struct Header: Decodable { let format: String; let schemaVersion: Int }
    private struct Envelope: Codable {
        let format: String
        let schemaVersion: Int
        let material: StudyMaterial
    }

    static func encode(_ material: StudyMaterial) throws -> Data {
        try material.validateForSharing()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(Envelope(format: "metra.material", schemaVersion: 1, material: material))
        guard data.count <= maximumBytes else { throw MetraMaterialError.tooLarge }
        return data
    }

    static func decode(_ data: Data) throws -> StudyMaterial {
        guard data.count <= maximumBytes else { throw MetraMaterialError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let header: Header
        do { header = try decoder.decode(Header.self, from: data) }
        catch { throw MetraMaterialError.invalidFile }
        guard header.format == "metra.material" else { throw MetraMaterialError.invalidFile }
        guard header.schemaVersion == 1 else { throw MetraMaterialError.unsupportedVersion }
        let envelope: Envelope
        do { envelope = try decoder.decode(Envelope.self, from: data) }
        catch { throw MetraMaterialError.invalidFile }
        try envelope.material.validateForSharing()
        return envelope.material
    }

    static func suggestedFilename(for material: StudyMaterial) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let stem = material.title.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
        return "\(String(stem.prefix(80)))_r\(material.revision)"
    }
}

nonisolated enum MetraImportResult: String, Sendable {
    case added = "Materi berhasil disimpan."
    case updated = "Materi diperbarui ke revisi terbaru."
    case unchanged = "Revisi materi ini sudah tersimpan."
    case older = "Salinan tersimpan lebih baru. Berkas lama diabaikan."
}

nonisolated enum MetraMaterialLibrary {
    /// Persist the returned list before replacing the in-memory library.
    static func merging(_ material: StudyMaterial, into materials: [StudyMaterial]) throws -> ([StudyMaterial], MetraImportResult) {
        try material.validateForSharing()
        var result = materials
        guard let index = result.firstIndex(where: { $0.id == material.id }) else {
            result.insert(material, at: 0)
            return (result, .added)
        }
        let existing = result[index]
        if material.revision < existing.revision { return (result, .older) }
        if material.revision == existing.revision {
            // File dates have second precision; compare the canonical file form.
            if existing.isValidated, try MetraMaterialFile.encode(existing) == MetraMaterialFile.encode(material) {
                return (result, .unchanged)
            }
            throw MetraMaterialError.conflictingRevision
        }
        result[index] = material
        return (result, .updated)
    }
}

private extension String {
    nonisolated var isMetraBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

#endif
