//
//  ClassroomNetworkContract.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 30/10/26.
//

import Foundation

typealias MetraContentPartDTO = MetraContentPart
typealias MetraChunkDTO = MetraChunk

nonisolated struct MetraTopicDTO: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var chunks: [MetraChunkDTO]

    init(id: UUID = UUID(), title: String, chunks: [MetraChunkDTO]) {
        self.id = id
        self.title = title
        self.chunks = chunks
    }

    init(from domain: MathTopicModel) {
        self.id = domain.id
        self.title = domain.title
        if !domain.chunks.isEmpty {
            self.chunks = domain.chunks
        } else {
            self.chunks = domain.content.map { item in
                switch item {
                case .text(let value), .analogy(let value), .visual(let value):
                    return MetraChunkDTO(parts: [.prose(value)])
                case .spokenMath(let value):
                    return MetraChunkDTO(parts: [.init(kind: .math, clearSpeak: value, simpleSpeak: value)])
                }
            }
        }
    }

    func toDomain(style: MetraSpeechStyle) -> MathTopicModel {
        let blocks: [MathTopicContent] = chunks.compactMap { chunk in
            let text = chunk.readingText(style: style).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return chunk.isStandaloneMath ? .spokenMath(text) : .text(text)
        }
        return MathTopicModel(id: id, title: title, content: blocks, chunks: chunks)
    }
}

nonisolated struct MathMaterialDTO: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let category: String
    let content: String
    let createdAt: Date
    let revision: Int
    let defaultSpeechStyle: MetraSpeechStyle
    let reviewStatus: MetraReviewStatus
    let validatedAt: Date?
    let topics: [MetraTopicDTO]
    let overview: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, category, createdAt, revision, defaultSpeechStyle, reviewStatus, validatedAt, topics, content, overview
    }

    init(
        id: UUID = UUID(),
        title: String,
        category: String = "Tester",
        content: String = "Tester",
        createdAt: Date = .now,
        revision: Int = 1,
        defaultSpeechStyle: MetraSpeechStyle = .clearSpeak,
        reviewStatus: MetraReviewStatus = .draft,
        validatedAt: Date? = nil,
        topics: [MetraTopicDTO]? = nil,
        overview: String? = nil
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
        self.topics = topics ?? [.init(title: title, chunks: [.init(parts: [.prose(content)])])]
        self.overview = overview
    }

    init(from domain: MathMaterialModel) {
        self.id = domain.id
        self.title = domain.title
        self.category = domain.category
        self.content = domain.content
        self.createdAt = domain.createdAt
        self.revision = domain.revision
        self.defaultSpeechStyle = domain.defaultSpeechStyle
        self.reviewStatus = domain.reviewStatus
        self.validatedAt = domain.validatedAt
        self.overview = domain.overview
        self.topics = domain.topics.isEmpty
            ? [.init(title: domain.title, chunks: [.init(parts: [.prose(domain.content)])])]
            : domain.topics.map { MetraTopicDTO(from: $0) }
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

        if let structured = try values.decodeIfPresent([MetraTopicDTO].self, forKey: .topics) {
            topics = structured
        } else {
            let legacy = try values.decode(String.self, forKey: .content)
            topics = [.init(title: title, chunks: [.init(parts: [.prose(legacy)])])]
        }

        if let decodedContent = try values.decodeIfPresent(String.self, forKey: .content) {
            content = decodedContent
        } else {
            let style = defaultSpeechStyle
            content = ([overview].compactMap { $0 } + topics.flatMap(\.chunks).map { $0.readingText(style: style) })
                .joined(separator: "\n\n")
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
        try values.encode(content, forKey: .content)
    }

    func toDomain(style: MetraSpeechStyle? = nil) -> MathMaterialModel {
        let resolvedStyle = style ?? defaultSpeechStyle
        let domainTopics = topics.map { $0.toDomain(style: resolvedStyle) }
        let allChunks = topics.flatMap(\.chunks)
        let resolvedContent: String
        if let style, style != defaultSpeechStyle, !allChunks.isEmpty {
            resolvedContent = ([overview].compactMap { $0 } + allChunks.map { $0.readingText(style: resolvedStyle) })
                .joined(separator: "\n\n")
        } else {
            resolvedContent = content
        }
        return MathMaterialModel(
            id: id,
            title: title,
            category: category,
            content: resolvedContent,
            createdAt: createdAt,
            revision: revision,
            defaultSpeechStyle: resolvedStyle,
            reviewStatus: reviewStatus,
            validatedAt: validatedAt,
            overview: overview,
            topics: domainTopics
        )
    }
}

nonisolated struct BroadcastPayload: Codable, Equatable, Sendable {
    let classroomName: String
    let teacherName: String
    let materials: [MathMaterialDTO]
    
    enum CodingKeys: String, CodingKey {
        case classroomName = "roomName"
        case teacherName
        case materials
    }
}

nonisolated enum NetworkMessageContract: Codable, Equatable, Sendable {
    case studentInformation(id: String, name: String)
    case classroomSync(BroadcastPayload)
    
    enum CodingKeys: String, CodingKey {
        case studentInformation = "studentHello"
        case classroomSync = "roomSync"
    }
}
