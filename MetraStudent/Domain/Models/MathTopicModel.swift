import Foundation

nonisolated struct MathTopicModel: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var content: [MathTopicContent]

    init(id: UUID = UUID(), title: String, content: [MathTopicContent] = []) {
        self.id = id
        self.title = title
        self.content = content
    }
}

nonisolated enum MathTopicContent: Hashable, Sendable {
    case text(String)
    case analogy(String)
    // A standalone mathematical expression written entirely as spoken words.
    case spokenMath(String)
    // A verbal description of a mathematical diagram, without relying on sight.
    case visual(String)
}
