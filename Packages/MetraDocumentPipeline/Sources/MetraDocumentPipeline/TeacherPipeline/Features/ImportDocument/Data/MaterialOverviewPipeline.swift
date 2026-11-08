#if os(iOS)
import Foundation

/// Bounded hierarchical summarization: every readable chunk participates, even
/// for ten-page files. Each request has a fresh context; no tail is truncated.
struct MaterialOverviewPipeline: MaterialOverviewGenerating {
    let summarizer: any OverviewTextSummarizing
    static let inputLimit = 4_000
    static let responseLimit = 1_200

    func generate(for material: StudyMaterial) async throws -> MaterialOverviewResult {
        try Task.checkCancellation()
        let topicIDs = material.topics.map(\.id)
        let count = material.topics.flatMap(\.chunks).count
        func result(_ text: String, provider: String, status: String, reason: String? = nil) -> MaterialOverviewResult {
            .init(text: text, provider: provider, status: status, sourceTopicIDs: topicIDs,
                  sourceChunkCount: count, reason: reason)
        }
        do {
            var inputs = Self.batches(Self.sourceSegments(material))
            guard !inputs.isEmpty else { throw MaterialOverviewUnavailable(reason: "no_readable_source") }
            // Responses are <= 1200 characters, so each reduction combines at
            // least two responses and strictly shrinks the number of requests.
            while inputs.count > 1 {
                var summaries: [String] = []
                for input in inputs {
                    try Task.checkCancellation()
                    summaries.append(try Self.accept(await summarizer.summarize(input)))
                }
                let reduced = Self.batches(summaries)
                guard reduced.count < inputs.count else { throw MaterialOverviewUnavailable(reason: "reduction_failed") }
                inputs = reduced
            }
            try Task.checkCancellation()
            let aiSummary = try Self.accept(await summarizer.summarize(inputs[0]))
            try Task.checkCancellation()
            let fullInfo = Self.composeMaterialInformation(for: material, aiSummary: aiSummary)
            return result(fullInfo, provider: "foundation_models", status: "generated")
        } catch {
            // Parent cancellation must never become a successful fallback import.
            try Task.checkCancellation()
            let reason = (error as? MaterialOverviewUnavailable)?.reason ?? "generation_failed"
            return result(Self.sourceOutline(material), provider: "source_outline", status: "fallback", reason: reason)
        }
    }

    static func accept(_ response: String) throws -> String {
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= responseLimit else {
            throw MaterialOverviewUnavailable(reason: "invalid_response")
        }
        return text
    }

    static func sourceSegments(_ material: StudyMaterial) -> [String] {
        let allChunks = material.topics.flatMap(\.chunks)
        let pages = uniqueOrderedPages(in: allChunks)
        let header = "Total halaman: \(max(1, pages.count)) halaman (\(pages.isEmpty ? "1" : pages.joined(separator: ", ")))."
        return [header] + material.topics.enumerated().flatMap { index, topic -> [String] in
            let pageInfo = topicPageDescription(for: topic) ?? "halaman 1"
            let heading = "Topik \(index + 1) (\(pageInfo)): \(topic.title)"
            return [heading] + topic.chunks.map { chunk in
                let label = chunk.pageLabel.map { "halaman \($0)" } ?? pageInfo
                return "[\(label) - \(topic.title)] " + chunk.readingText(style: .clearSpeak)
            }
        }
    }

    static func batches(_ segments: [String]) -> [String] {
        var batches: [String] = []
        var current = ""
        for segment in segments {
            var rest = segment[...]
            // Long single chunks are split instead of silently discarded.
            while !rest.isEmpty {
                let room = inputLimit - current.count - (current.isEmpty ? 0 : 2)
                if room <= 0 { batches.append(current); current = ""; continue }
                let end = rest.index(rest.startIndex, offsetBy: min(room, rest.count))
                if !current.isEmpty { current += "\n\n" }
                current += rest[..<end]
                rest = rest[end...]
                if !rest.isEmpty { batches.append(current); current = "" }
            }
        }
        if !current.isEmpty { batches.append(current) }
        return batches
    }

    static func sourceOutline(_ material: StudyMaterial) -> String {
        composeMaterialInformation(for: material, aiSummary: nil)
    }

    /// Menyusun Informasi Materi ringkas bergaya Rekomendasi 2 untuk siswa tunanetra:
    /// "Materi ini terdiri dari X halaman. Halaman A membahas ..., halaman B membahas ..., dan halaman C sampai D berisi ..."
    static func composeMaterialInformation(for material: StudyMaterial, aiSummary: String?) -> String {
        let allChunks = material.topics.flatMap(\.chunks)
        let pages = uniqueOrderedPages(in: allChunks)
        let pageCount = max(1, pages.count)

        if let ai = aiSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !ai.isEmpty {
            let lower = ai.lowercased()
            if lower.hasPrefix("materi ini terdiri dari ") && lower.contains("halaman") {
                return ai
            }
            if lower.contains("halaman ") {
                return "Materi ini terdiri dari \(pageCount) halaman. \(ai)"
            }
        }

        return buildPageByPageNarrative(for: material, pages: pages)
    }

    private static func buildPageByPageNarrative(for material: StudyMaterial, pages: [String]) -> String {
        let pageCount = max(1, pages.count)
        let clauses = pageClauses(for: material, pages: pages)

        if pageCount == 1 {
            let pageLabel = pages.first ?? "1"
            let detail = clauses.first?.detail ?? "materi \(material.title)"
            return "Materi ini terdiri dari 1 halaman (halaman \(pageLabel)) yang \(detail)."
        }

        guard !clauses.isEmpty else {
            return "Materi ini terdiri dari \(pageCount) halaman."
        }

        let formattedClauses = clauses.enumerated().map { index, item -> String in
            let pagePrefix = index == 0
                ? item.pagePhrase.prefix(1).uppercased() + item.pagePhrase.dropFirst()
                : item.pagePhrase
            return "\(pagePrefix) \(item.detail)"
        }
        return "Materi ini terdiri dari \(pageCount) halaman. \(joinIndonesianList(formattedClauses))."
    }

    private struct PageClause {
        let pagePhrase: String
        let detail: String
    }

    private static func pageClauses(for material: StudyMaterial, pages: [String]) -> [PageClause] {
        // Jika ada beberapa topik, petakan berdasarkan topik beserta halaman/rentang halamannya.
        // Jika hanya ada 1 topik tapi multi-halaman, petakan per halaman agar tiap halaman punya info bahasan.
        if material.topics.count > 1 || pages.count <= 1 {
            return material.topics.prefix(12).compactMap { topic -> PageClause? in
                let pagePhrase = topicPageDescription(for: topic) ?? (pages.first.map { "halaman \($0)" } ?? "halaman 1")
                let detail = describeSection(title: topic.title, chunks: topic.chunks, fallbackTitle: material.title)
                return PageClause(pagePhrase: pagePhrase, detail: detail)
            }
        } else {
            let allChunks = material.topics.flatMap(\.chunks)
            let topicTitle = material.topics.first?.title ?? material.title
            return pages.prefix(12).compactMap { page -> PageClause? in
                let pageChunks = allChunks.filter { $0.pageLabel?.trimmingCharacters(in: .whitespacesAndNewlines) == page }
                guard !pageChunks.isEmpty else { return nil }
                let detail = describeSection(title: topicTitle, chunks: pageChunks, fallbackTitle: material.title)
                return PageClause(pagePhrase: "halaman \(page)", detail: detail)
            }
        }
    }

    private static func describeSection(title: String, chunks: [MetraChunk], fallbackTitle: String) -> String {
        var cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty { cleanTitle = fallbackTitle.trimmingCharacters(in: .whitespacesAndNewlines) }
        cleanTitle = String(cleanTitle.prefix(120))
        let lowerTitle = cleanTitle.lowercased()

        var visualHint: String?
        var hasMath = false
        var questionCount = 0
        var hasChoices = false
        var proseCount = 0

        let visualMap: [(prefix: String, label: String)] = [
            ("diagram lingkaran", "diagram lingkaran"),
            ("diagram batang", "diagram batang"),
            ("grafik garis", "grafik garis"),
            ("gambar geometri", "gambar geometri"),
            ("ilustrasi.", "gambar ilustrasi"),
            ("gambar.", "gambar")
        ]

        for chunk in chunks {
            let text = chunk.readingText(style: .clearSpeak).trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = text.lowercased()
            if chunk.parts.contains(where: { $0.kind == .math }) {
                hasMath = true
            }
            if let matchedVisual = visualMap.first(where: { lower.hasPrefix($0.prefix) }) {
                if visualHint == nil { visualHint = matchedVisual.label }
            } else if text.range(of: #"^(?:Soal\s+[0-9]{1,3}|[0-9]{1,3}[.)])\s+\S"#, options: .regularExpression) != nil {
                questionCount += 1
            } else if text.range(of: #"^[A-Ea-e][.)]\s+\S"#, options: .regularExpression) != nil {
                hasChoices = true
            } else if !text.isEmpty {
                proseCount += 1
            }
        }

        let titleMentionsExercise = lowerTitle.contains("latihan") || lowerTitle.contains("soal") || lowerTitle.contains("uji ") || lowerTitle.contains("evaluasi")
        let titleMentionsFormula = lowerTitle.contains("rumus")

        // Jika bagian ini murni berisi latihan soal
        if proseCount == 0 && questionCount > 0 {
            let soalType = hasChoices ? "latihan soal pilihan ganda" : "latihan soal"
            if titleMentionsExercise {
                return hasChoices && !lowerTitle.contains("pilihan ganda")
                    ? "berisi \(cleanTitle) pilihan ganda"
                    : "berisi \(cleanTitle)"
            }
            return "berisi \(soalType) \(cleanTitle)"
        }

        var extras: [String] = []
        if let visualHint {
            extras.append("disertai \(visualHint)")
        } else if hasMath && !titleMentionsFormula {
            extras.append("beserta rumusnya")
        }
        if questionCount > 0 && !titleMentionsExercise {
            extras.append(hasChoices ? "dan latihan soal pilihan ganda" : "dan latihan soal")
        }

        if extras.isEmpty {
            return titleMentionsExercise ? "berisi \(cleanTitle)" : "membahas \(cleanTitle)"
        }
        return "membahas \(cleanTitle) " + extras.joined(separator: " ")
    }

    static func topicPageDescription(for topic: MetraTopic) -> String? {
        let pages = uniqueOrderedPages(in: topic.chunks)
        guard !pages.isEmpty else { return nil }
        if pages.count == 1 {
            return "halaman \(pages[0])"
        }
        if let first = pages.first, let last = pages.last {
            return "halaman \(first) sampai \(last)"
        }
        return nil
    }

    static func uniqueOrderedPages(in chunks: [MetraChunk]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for chunk in chunks {
            guard let label = chunk.pageLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !label.isEmpty,
                  seen.insert(label).inserted else { continue }
            ordered.append(label)
        }
        return ordered
    }

    private static func joinIndonesianList(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) dan \(items[1])"
        default:
            let head = items.dropLast().joined(separator: ", ")
            return "\(head), dan \(items[items.count - 1])"
        }
    }
}

#endif
