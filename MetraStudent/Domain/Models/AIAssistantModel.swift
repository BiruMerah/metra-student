//
//  AIAssistantModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 01/11/26.
//

import Foundation
import NaturalLanguage

nonisolated enum AIAssistantAction: String, CaseIterable, Identifiable {
    case summarize, explain
    
    var id: String { rawValue }
    var title: String { self == .summarize ? "Simpulkan hingga kalimat ini" : "Jelaskan lebih lanjut" }
    var resultTitle: String { self == .summarize ? "Ringkasan" : "Penjelasan" }
    var symbol: String { self == .summarize ? "text.alignleft" : "lightbulb" }
    var alternative: Self { self == .summarize ? .explain : .summarize }
}

nonisolated struct AIAssistantSentence: Equatable {
    let id: String
    let text: String
}

nonisolated struct AIAssistantSelection: Identifiable, Equatable {
    let topicID: UUID
    let topicTitle: String
    let sentenceID: String
    let sentencesThroughSelection: [AIAssistantSentence]
    
    var id: String { "\(topicID.uuidString).\(sentenceID)" }
    var selectedSentence: String { sentencesThroughSelection.last?.text ?? "" }
    
    static func make(
        topicID: UUID,
        topicTitle: String,
        sentences: [AIAssistantSentence],
        selectedID: String
    ) throws -> Self {
        guard let index = sentences.firstIndex(where: { $0.id == selectedID }) else {
            throw MetraAssistantFailure.message("Kalimat tidak ditemukan. Pilih kembali bagian materi yang ingin dipelajari.")
        }
        return Self(topicID: topicID, topicTitle: topicTitle, sentenceID: selectedID,
                    sentencesThroughSelection: Array(sentences.prefix(index + 1)))
    }
    
    func sourceSentences(for action: AIAssistantAction) -> [String] {
        if action == .summarize { return sentencesThroughSelection.map(\.text) }
        
        // Retrieve only earlier context, keeping its original reading order.
        let previous = Array(sentencesThroughSelection.dropLast())
        let selectedWords = Self.words(selectedSentence)
        var ranked: [(index: Int, score: Int)] = []
        for (index, sentence) in previous.enumerated() {
            let score = Self.words(sentence.text).intersection(selectedWords).count
            if score > 0 { ranked.append((index, score)) }
        }
        ranked.sort { left, right in
            left.score == right.score ? left.index > right.index : left.score > right.score
        }
        var indices = Set(previous.indices.suffix(4))
        for item in ranked.prefix(3) { indices.insert(item.index) }
        return indices.sorted().map { previous[$0].text } + [selectedSentence]
    }
    
    private static func words(_ text: String) -> Set<String> {
        let ignored: Set<String> = ["yang", "dan", "dengan", "dari", "untuk", "adalah", "atau", "pada", "ini", "itu", "sebuah"]
        return Set(text.lowercased().split { !$0.isLetter }.map(String.init).filter {
            $0.count > 2 && !ignored.contains($0)
        })
    }
}

nonisolated struct AIAssistantResult: Identifiable, Equatable {
    let id: UUID
    let action: AIAssistantAction
    let points: [String]
    
    static func validated(action: AIAssistantAction, points: [String]) throws -> Self {
        let clean = points.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !clean.isEmpty, clean.allSatisfy({ !$0.isEmpty }) else {
            throw MetraAssistantFailure.message("Hasil masih kosong. Silakan coba lagi.")
        }
        switch action {
        case .summarize:
            guard clean.count <= 5, clean.allSatisfy({ wordCount($0) <= 24 }),
                  clean.reduce(0, { $0 + wordCount($1) }) <= 100 else {
                throw MetraAssistantFailure.message("Ringkasan belum cukup singkat. Silakan coba lagi untuk maksimal lima poin ringkas.")
            }
            let distinct = Set(clean.map { $0.lowercased().split { !$0.isLetter }.joined(separator: " ") })
            guard distinct.count == clean.count else {
                throw MetraAssistantFailure.message("Ringkasan masih mengulang poin yang sama. Silakan coba lagi.")
            }
        case .explain:
            guard clean.count == 1, clean[0].count <= 100 else {
                throw MetraAssistantFailure.message("Penjelasan masih melebihi seratus karakter. Silakan coba lagi.")
            }
        }
        guard clean.allSatisfy(isVerbalMath) else {
            throw MetraAssistantFailure.message("Hasil belum sepenuhnya matematika verbal. Silakan coba lagi.")
        }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(clean.joined(separator: " "))
        if let language = recognizer.languageHypotheses(withMaximum: 1).first,
           language.value > 0.9, ![NLLanguage.indonesian, .malay].contains(language.key) {
            throw MetraAssistantFailure.message("Hasil belum dalam bahasa Indonesia. Silakan coba lagi.")
        }
        return Self(id: UUID(), action: action, points: clean)
    }
    
    static func wordCount(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }
    
    static func isVerbalMath(_ text: String) -> Bool {
        guard !text.unicodeScalars.contains(where: {
            $0.properties.numericType != nil || [.mathSymbol, .currencySymbol, .otherSymbol].contains($0.properties.generalCategory)
        }) else { return false }
        // Reject formula/Markdown syntax and unspoken variable/unit abbreviations.
        return text.range(of: #"[=+*/\\^<>×÷−%$`#{}\[\]_]|\b[xyzXYZ]\b|\b(?:cm|mm|km|ml|kg)\b|(?<!\p{L})-|-(?!\p{L})|(?m)^\s*•"#,
                          options: .regularExpression) == nil
    }
}

nonisolated enum AIAssistantProgress { case translatingSource, generating, translatingResult }

nonisolated enum AIAssistantFailure: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}

nonisolated enum MathGuard {
    private static let units = [
        #"\b(?:centimet(?:er|re)s?|sentimeter|cm)\b"#,
        #"\b(?:millimet(?:er|re)s?|milimeter|mm)\b"#,
        #"\b(?:kilomet(?:er|re)s?|kilometer|km)\b"#,
        #"\b(?:met(?:er|re)s?|m)\b"#,
        #"\b(?:inch(?:es)?|inci)\b"#,
        #"\b(?:foot|feet|ft|kaki)\b"#,
        #"\b(?:lit(?:er|re)s?)\b"#,
        #"\b(?:millilit(?:er|re)s?|mililiter|ml)\b"#
    ]
    
    static func preservesUnits(points: [String], source: [String]) -> Bool {
        let input = source.joined(separator: " ").lowercased()
        let output = points.joined(separator: " ").lowercased()
        return units.allSatisfy { pattern in
            output.range(of: pattern, options: .regularExpression) == nil ||
            input.range(of: pattern, options: .regularExpression) != nil
        }
    }
}
