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
    var defaultSpeechStyle: MetraSpeechStyle = .clearSpeak
    var reviewStatus: MetraReviewStatus = .draft
    var validatedAt: Date? = nil
    var overview: String? = nil
    var topics: [MathTopicModel] = []
    
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
        overview: String? = nil,
        topics: [MathTopicModel] = []
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
        self.topics = topics
    }

    var materialOverview: MaterialOverview {
        var seenPages = Set<String>()
        let pages = topics.flatMap(\.chunks).compactMap(\.pageLabel).filter { seenPages.insert($0).inserted }
        let firstPage = pages.first.flatMap(Int.init) ?? 1
        return MaterialOverview(
            chapter: title,
            subchapter: topics.first?.title ?? category,
            pageNumber: firstPage,
            questionCount: 0,
            summaryText: overview,
            topicCount: topics.count,
            pageLabels: pages
        )
    }
}
