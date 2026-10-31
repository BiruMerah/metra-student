import Foundation

enum TopicSentenceChunker {
    /// Content can arrive as a paragraph even when its block is called `sentence`.
    /// Split before constructing either the visual labels or the accessibility list.
    static func sentences(in text: String) -> [String] {
        var sentences: [String] = []
        let paragraphs = text.components(separatedBy: .newlines)
        for paragraph in paragraphs {
            let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedParagraph.isEmpty else { continue }
            var found = false
            paragraph.enumerateSubstrings(in: paragraph.startIndex..<paragraph.endIndex, options: .bySentences) { sentence, _, _, _ in
                guard let sentence else { return }
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                    found = true
                }
            }
            if !found {
                sentences.append(trimmedParagraph)
            }
        }
        return sentences
    }
}
