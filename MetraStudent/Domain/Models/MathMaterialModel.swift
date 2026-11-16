//
//  MathMaterialModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

nonisolated struct MaterialOverview: Equatable, Hashable, Sendable {
    let chapter: String
    let subchapter: String
    let pageNumber: Int
    let questionCount: Int
    let summaryText: String?
    let topicCount: Int
    let pageLabels: [String]
    let sourceTitle: String?

    init(
        chapter: String = "",
        subchapter: String = "",
        pageNumber: Int = 1,
        questionCount: Int = 0,
        summaryText: String? = nil,
        topicCount: Int = 0,
        pageLabels: [String] = [],
        sourceTitle: String? = nil
    ) {
        self.chapter = chapter
        self.subchapter = subchapter
        self.pageNumber = pageNumber
        self.questionCount = questionCount
        self.summaryText = summaryText
        self.topicCount = topicCount
        self.pageLabels = pageLabels
        self.sourceTitle = sourceTitle
    }

    static let sample = MaterialOverview(
        chapter: "Bab I - Persamaan Linear Satu Variabel",
        subchapter: "Mengenal dan Menyelesaikan Persamaan Linear",
        pageNumber: 21,
        questionCount: 1,
        summaryText: "Materi ini membahas persamaan linear satu variabel dan langkah penyelesaiannya.",
        topicCount: 4,
        pageLabels: ["21"],
        sourceTitle: "Matematika untuk SMP/MTs Kelas IX"
    )
}

nonisolated struct MathMaterialModel: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var title: String
    var category: String
    var content: String
    var createdAt: Date = Date()
    var revision: Int = 1
    var defaultSpeechStyle: SpeechStyle = .clearSpeak
    var reviewStatus: ReviewStatus = .draft
    var validatedAt: Date? = nil
    var overview: String? = nil
    var sections: [MathSectionModel] = []
    var isFromTeacher: Bool = false
    var sourceChannelName: String? = nil
    var sourceTeacherName: String? = nil
    var sourceTitle: String? = nil
    var pageLabelsAreSource: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id, title, category, content, createdAt, revision
        case defaultSpeechStyle, reviewStatus, validatedAt, overview, sections
        case isFromTeacher, sourceChannelName, sourceTeacherName, sourceTitle, pageLabelsAreSource
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        category: String = "Tester",
        content: String = "Tester",
        createdAt: Date = .now,
        revision: Int = 1,
        defaultSpeechStyle: SpeechStyle = .clearSpeak,
        reviewStatus: ReviewStatus = .draft,
        validatedAt: Date? = nil,
        overview: String? = nil,
        sections: [MathSectionModel] = [],
        isFromTeacher: Bool = false,
        sourceChannelName: String? = nil,
        sourceTeacherName: String? = nil,
        sourceTitle: String? = nil,
        pageLabelsAreSource: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.content = content
        self.createdAt = createdAt
        self.revision = revision
        self.defaultSpeechStyle = defaultSpeechStyle
        self.reviewStatus = reviewStatus
        self.validatedAt = validatedAt
        self.overview = overview
        self.sections = sections
        self.isFromTeacher = isFromTeacher
        self.sourceChannelName = Self.normalizedMetadata(sourceChannelName)
        self.sourceTeacherName = Self.normalizedMetadata(sourceTeacherName)
        self.sourceTitle = Self.normalizedMetadata(sourceTitle)
        self.pageLabelsAreSource = pageLabelsAreSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Tester"
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? "Tester"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        defaultSpeechStyle = try container.decodeIfPresent(SpeechStyle.self, forKey: .defaultSpeechStyle) ?? .clearSpeak
        reviewStatus = try container.decodeIfPresent(ReviewStatus.self, forKey: .reviewStatus) ?? .draft
        validatedAt = try container.decodeIfPresent(Date.self, forKey: .validatedAt)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        sections = try container.decodeIfPresent([MathSectionModel].self, forKey: .sections) ?? []
        isFromTeacher = try container.decodeIfPresent(Bool.self, forKey: .isFromTeacher) ?? false
        sourceChannelName = Self.normalizedMetadata(try container.decodeIfPresent(String.self, forKey: .sourceChannelName))
        sourceTeacherName = Self.normalizedMetadata(try container.decodeIfPresent(String.self, forKey: .sourceTeacherName))
        sourceTitle = Self.normalizedMetadata(try container.decodeIfPresent(String.self, forKey: .sourceTitle))
        pageLabelsAreSource = try container.decodeIfPresent(Bool.self, forKey: .pageLabelsAreSource) ?? false
    }

    /// Marks this material as coming from a teacher's iCloud channel.
    func withTeacherSource(channelName: String? = nil, teacherName: String? = nil) -> MathMaterialModel {
        var copy = self
        copy.isFromTeacher = true
        if let channelName = Self.normalizedMetadata(channelName) {
            copy.sourceChannelName = channelName
        }
        if let teacherName = Self.normalizedMetadata(teacherName),
           teacherName.caseInsensitiveCompare("Tidak diketahui") != .orderedSame {
            copy.sourceTeacherName = teacherName
        }
        return copy
    }

    private static func normalizedMetadata(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    var materialOverview: MaterialOverview {
        var seenPages = Set<String>()
        let pages = pageLabelsAreSource
            ? sections.flatMap(\.chunks).compactMap(\.pageLabel).filter { seenPages.insert($0).inserted }
            : []
        let firstPage = pages.first.flatMap(Int.init) ?? 0
        return MaterialOverview(
            chapter: title,
            subchapter: sections.first?.title ?? category,
            pageNumber: firstPage,
            questionCount: 0,
            summaryText: overview,
            topicCount: sections.count,
            pageLabels: pages,
            sourceTitle: sourceTitle
        )
    }

    func withSpeechStyle(_ speechStyle: SpeechStyle) -> MathMaterialModel {
        let updatedSections = sections.map { $0.withSpeechStyle(speechStyle) }
        let allChunks = sections.flatMap(\.chunks)
        let updatedContent: String
        if !allChunks.isEmpty {
            updatedContent = ([overview].compactMap { $0 } + allChunks.map { $0.readingText(speechStyle: speechStyle) })
                .joined(separator: "\n\n")
        } else {
            updatedContent = content
        }
        return MathMaterialModel(
            id: id,
            title: title,
            category: category,
            content: updatedContent,
            createdAt: createdAt,
            revision: revision,
            defaultSpeechStyle: speechStyle,
            reviewStatus: reviewStatus,
            validatedAt: validatedAt,
            overview: overview,
            sections: updatedSections,
            isFromTeacher: isFromTeacher,
            sourceChannelName: sourceChannelName,
            sourceTeacherName: sourceTeacherName,
            sourceTitle: sourceTitle,
            pageLabelsAreSource: pageLabelsAreSource
        )
    }
}

// MARK: - Portable Envelope Decoding (from Teacher app / CloudKit)
nonisolated struct PortableEnvelope: Decodable, Sendable {
    let format: String?
    let schemaVersion: Int?
    let material: PortableMaterial
}

nonisolated struct PortableMaterial: Decodable, Sendable {
    struct Topic: Decodable, Sendable {
        let id: UUID
        let title: String
        let chunks: [MathChunk]
    }

    let id: UUID
    let title: String
    let category: String?
    let content: String?
    let createdAt: Date?
    let revision: Int?
    let defaultSpeechStyle: SpeechStyle?
    let reviewStatus: ReviewStatus?
    let validatedAt: Date?
    let overview: String?
    let sourceTitle: String?
    let pageLabelsAreSource: Bool?
    let topics: [Topic]?

    var studentMaterial: MathMaterialModel {
        let mappedSections: [MathSectionModel] = (topics ?? []).map { topic in
            MathSectionModel(
                id: topic.id,
                title: topic.title,
                content: [],
                chunks: topic.chunks
            )
        }

        return MathMaterialModel(
            id: id,
            title: title,
            category: category ?? "Matematika",
            content: content ?? "",
            createdAt: createdAt ?? Date(),
            revision: revision ?? 1,
            defaultSpeechStyle: defaultSpeechStyle ?? .clearSpeak,
            reviewStatus: reviewStatus ?? .draft,
            validatedAt: validatedAt,
            overview: overview,
            sections: mappedSections,
            sourceTitle: sourceTitle,
            pageLabelsAreSource: pageLabelsAreSource ?? false
        )
    }
}
