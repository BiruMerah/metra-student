import Foundation
import Observation

struct TopicReadingBlock: Identifiable {
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
final class TopicViewModel {
    private(set) var currentTopicIndex: Int
    private(set) var readingBlocks: [TopicReadingBlock] = []
    private let topics: [MathTopicModel]
    private let assistantEngineFactory: ((any AssistantTranslatingProtocol) -> any AssistantProvidingProtocol)?
    private var assistantSessions: [String: AIAssistantViewModel] = [:]

    var topic: MathTopicModel { topics[currentTopicIndex] }
    var progress: String { "Topik \(currentTopicIndex + 1) dari \(topics.count)" }
    var hasPreviousTopic: Bool { currentTopicIndex > 0 }
    var hasNextTopic: Bool { currentTopicIndex + 1 < topics.count }
    var lastSentenceID: String? {
        readingBlocks.last(where: { !$0.sentences.isEmpty })?.sentences.last?.id
    }

    init(
        topics: [MathTopicModel],
        initialTopicIndex: Int = 0,
        assistantEngineFactory: ((any AssistantTranslatingProtocol) -> any AssistantProvidingProtocol)? = nil
    ) {
        precondition(!topics.isEmpty, "A topic reader needs at least one topic")
        self.topics = topics
        self.currentTopicIndex = min(max(initialTopicIndex, 0), topics.count - 1)
        self.assistantEngineFactory = assistantEngineFactory
        prepareContent()
    }

    func previousTopic() {
        guard hasPreviousTopic else { return }
        currentTopicIndex -= 1
        prepareContent()
    }

    func nextTopic() {
        guard hasNextTopic else { return }
        currentTopicIndex += 1
        prepareContent()
    }

    func assistantSelection(sentenceID: String) throws -> MetraAssistantSelection {
        let sentences = readingBlocks.flatMap(\.sentences).map {
            MetraAssistantSentence(id: $0.id, text: $0.text)
        }
        return try MetraAssistantSelection.make(
            topicID: topic.id,
            topicTitle: topic.title,
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
        readingBlocks = topic.content.enumerated().map { index, content in
            let kind: TopicReadingBlock.Kind
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
                TopicReadingBlock.Sentence(id: "\(index).\(sentenceIndex)", text: sentence)
            }
            return TopicReadingBlock(id: index, kind: kind, sentences: sentences)
        }
    }
}

// Demo content for the existing material-detail prototype and Xcode previews.
// Replace this source when classroom materials provide structured topics.
// Write mathematical content as spoken Indonesian, including numbers,
// operations, and the variable name "eks", so text and VoiceOver match.
extension TopicViewModel {
    static let sampleTopics: [MathTopicModel] = MathTopicModel.sampleTopics
}
