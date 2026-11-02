//
//  MathMaterialEntity.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation
import SwiftData

@Model
final class MathMaterialEntity {
    @Attribute(.unique)
    var id: UUID
    
    var title: String
    var category: String = ""
    var content: String = ""
    var createdAt: Date = Date.now
    var revision: Int = 1
    var defaultSpeechStyleRaw: String = MetraSpeechStyle.clearSpeak.rawValue
    var reviewStatusRaw: String = MetraReviewStatus.draft.rawValue
    var validatedAt: Date? = nil
    var overview: String? = nil
    var topicsData: Data = Data()
    
    init(
        id: UUID = UUID(),
        title: String,
        category: String = "",
        content: String = "",
        createdAt: Date = .now,
        revision: Int = 1,
        defaultSpeechStyleRaw: String = MetraSpeechStyle.clearSpeak.rawValue,
        reviewStatusRaw: String = MetraReviewStatus.draft.rawValue,
        validatedAt: Date? = nil,
        overview: String? = nil,
        topicsData: Data = Data()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.content = content
        self.createdAt = createdAt
        self.revision = revision
        self.defaultSpeechStyleRaw = defaultSpeechStyleRaw
        self.reviewStatusRaw = reviewStatusRaw
        self.validatedAt = validatedAt
        self.overview = overview
        self.topicsData = topicsData
    }
    
    // MARK: - Mapper
    func toDomain() -> MathMaterialModel {
        let decodedTopics = (try? JSONDecoder().decode([MathTopicModel].self, from: topicsData)) ?? []
        return MathMaterialModel(
            id: self.id,
            title: self.title,
            category: self.category,
            content: self.content,
            createdAt: self.createdAt,
            revision: self.revision,
            defaultSpeechStyle: MetraSpeechStyle(rawValue: self.defaultSpeechStyleRaw) ?? .clearSpeak,
            reviewStatus: MetraReviewStatus(rawValue: self.reviewStatusRaw) ?? .draft,
            validatedAt: self.validatedAt,
            overview: self.overview,
            topics: decodedTopics
        )
    }
    
    func update(from domain: MathMaterialModel) {
        self.title = domain.title
        self.category = domain.category
        self.content = domain.content
        self.createdAt = domain.createdAt
        self.revision = domain.revision
        self.defaultSpeechStyleRaw = domain.defaultSpeechStyle.rawValue
        self.reviewStatusRaw = domain.reviewStatus.rawValue
        self.validatedAt = domain.validatedAt
        self.overview = domain.overview
        self.topicsData = (try? JSONEncoder().encode(domain.topics)) ?? Data()
    }
    
    static func from(domain: MathMaterialModel) -> MathMaterialEntity {
        let encodedTopics = (try? JSONEncoder().encode(domain.topics)) ?? Data()
        return MathMaterialEntity(
            id: domain.id,
            title: domain.title,
            category: domain.category,
            content: domain.content,
            createdAt: domain.createdAt,
            revision: domain.revision,
            defaultSpeechStyleRaw: domain.defaultSpeechStyle.rawValue,
            reviewStatusRaw: domain.reviewStatus.rawValue,
            validatedAt: domain.validatedAt,
            overview: domain.overview,
            topicsData: encodedTopics
        )
    }
}
