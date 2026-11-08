//
//  SectionViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import Foundation
import Observation

struct SectionReadingBlock: Identifiable {
    enum Kind {
        case text
        case analogy
        case spokenMath
        case visual
    }

    struct Sentence: Identifiable {
        let id: String
        let text: String
    }

    let id: Int
    let kind: Kind
    let sentences: [Sentence]
}

@Observable
@MainActor
final class SectionViewModel {
    private(set) var currentSectionIndex: Int
    private(set) var readingBlocks: [SectionReadingBlock] = []
    var speechStyle: SpeechStyle {
        didSet {
            guard oldValue != speechStyle else { return }
            assistantSessions.removeAll()
            prepareContent()
        }
    }
    private let sections: [MathSectionModel]
    private let assistantEngineFactory: ((any AssistantTranslatingProtocol) -> any AssistantProvidingProtocol)?
    private var assistantSessions: [String: AIAssistantViewModel] = [:]

    var section: MathSectionModel { sections[currentSectionIndex] }
    var progress: String { "Segmen \(currentSectionIndex + 1) dari \(sections.count)" }
    var hasPreviousSection: Bool { currentSectionIndex > 0 }
    var hasNextSection: Bool { currentSectionIndex + 1 < sections.count }
    var lastSentenceID: String? {
        readingBlocks.last(where: { !$0.sentences.isEmpty })?.sentences.last?.id
    }

    init(
        sections: [MathSectionModel],
        initialSectionIndex: Int = 0,
        initialSpeechStyle: SpeechStyle = .clearSpeak,
        assistantEngineFactory: ((any AssistantTranslatingProtocol) -> any AssistantProvidingProtocol)? = nil
    ) {
        precondition(!sections.isEmpty, "A section reader needs at least one section")
        self.sections = sections
        self.currentSectionIndex = min(max(initialSectionIndex, 0), sections.count - 1)
        self.speechStyle = initialSpeechStyle
        self.assistantEngineFactory = assistantEngineFactory
        prepareContent()
    }

    func previousSection() {
        guard hasPreviousSection else { return }
        currentSectionIndex -= 1
        prepareContent()
    }

    func nextSection() {
        guard hasNextSection else { return }
        currentSectionIndex += 1
        prepareContent()
    }

    func assistantSelection(sentenceID: String) throws -> AIAssistantSelection {
        let sentences = readingBlocks.flatMap(\.sentences).map {
            AIAssistantSentence(id: $0.id, text: $0.text)
        }
        return try AIAssistantSelection.make(
            topicID: section.id,
            topicTitle: section.title,
            sentences: sentences,
            selectedID: sentenceID
        )
    }

    func assistantSession(
        sentenceID: String,
        engine: (any AssistantProvidingProtocol)? = nil
    ) throws -> AIAssistantViewModel {
        let selection = try assistantSelection(sentenceID: sentenceID)
        if let existing = assistantSessions[selection.id] { return existing }

        let session = AIAssistantViewModel(
            selection: selection,
            engine: engine,
            engineFactory: assistantEngineFactory
        )
        assistantSessions[selection.id] = session
        return session
    }

    private func prepareContent() {
        let activeContent = section.content(for: speechStyle)
        readingBlocks = activeContent.enumerated().map { index, content in
            let kind: SectionReadingBlock.Kind
            let text: String

            switch content {
            case .text(let value):
                kind = .text
                text = value
                
            case .analogy(let value):
                kind = .analogy
                text = value
                
            case .spokenMath(let value):
                kind = .spokenMath
                text = value
                
            case .visual(let value):
                kind = .visual
                text = value
            }

            let sentences = TopicSentenceChunker.sentences(in: text).enumerated().map { sentenceIndex, sentence in
                SectionReadingBlock.Sentence(id: "\(index).\(sentenceIndex)", text: sentence)
            }
            return SectionReadingBlock(id: index, kind: kind, sentences: sentences)
        }
    }
}

// Demo content for the existing material-detail prototype and Xcode previews.
// Replace this source when classroom materials provide structured topics.
// Write mathematical content as spoken Indonesian, including numbers,
// operations, and the variable name "eks", so text and VoiceOver match.
extension SectionViewModel {
    static let sampleSections: [MathSectionModel] = MathSectionModel.sampleSections
}

