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

    init(
        chapter: String = "",
        subchapter: String = "",
        pageNumber: Int = 1,
        questionCount: Int = 0,
        summaryText: String? = nil,
        topicCount: Int = 0,
        pageLabels: [String] = []
    ) {
        self.chapter = chapter
        self.subchapter = subchapter
        self.pageNumber = pageNumber
        self.questionCount = questionCount
        self.summaryText = summaryText
        self.topicCount = topicCount
        self.pageLabels = pageLabels
    }

    static let sample = MaterialOverview(
        chapter: "Bab I - Persamaan Linear Satu Variabel",
        subchapter: "Mengenal dan Menyelesaikan Persamaan Linear",
        pageNumber: 21,
        questionCount: 1,
        summaryText: "Materi ini membahas persamaan linear satu variabel dan langkah penyelesaiannya.",
        topicCount: 4,
        pageLabels: ["21"]
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
        sections: [MathSectionModel] = []
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
    }

    var materialOverview: MaterialOverview {
        var seenPages = Set<String>()
        let pages = sections.flatMap(\.chunks).compactMap(\.pageLabel).filter { seenPages.insert($0).inserted }
        let firstPage = pages.first.flatMap(Int.init) ?? 1
        return MaterialOverview(
            chapter: title,
            subchapter: sections.first?.title ?? category,
            pageNumber: firstPage,
            questionCount: 0,
            summaryText: overview,
            topicCount: sections.count,
            pageLabels: pages
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
            sections: updatedSections
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
            sections: mappedSections
        )
    }
}
