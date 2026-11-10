#if os(iOS)
import Foundation
import UIKit

@MainActor
final class TeacherMaterialExtractionService: MaterialPreparationProtocol {
    private let engine = OnDeviceExtractionService()
    private let inspector = TeacherPageInspector()
    private let overviewGenerator: any MaterialOverviewGenerating

    init(overviewGenerator: any MaterialOverviewGenerating = MaterialOverviewPipeline(summarizer: FoundationMaterialOverviewRuntime())) {
        self.overviewGenerator = overviewGenerator
    }

    func inspect(pages: [MaterialImageInput], retry: Bool = false,
                 onAssessment: @escaping @MainActor (TeacherPageAssessment) -> Void = { _ in },
                 onProgress: @escaping @MainActor (String) -> Void) async throws -> [TeacherPageAssessment] {
        try await inspector.inspect(pages, retry: retry, onAssessment: onAssessment, onProgress: onProgress)
    }
    var modelStatus: String { engine.diagramModelStatus }
    var sourceChunks: [ReadyChunk] { engine.lastReadyDocument?.chunks ?? [] }

    func cancel() { engine.cancel() }

    func extract(pages: [MaterialImageInput], title: String, firstBookPage: Int?, bookPageLabels: [Int]? = nil, uncertainPageIDs: Set<UUID> = [],
                 onProgress: @escaping @MainActor (String) -> Void) async throws -> TeacherExtractionResult {
        let idleTimerWasDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = idleTimerWasDisabled }
        let sources = try await inspector.preparedSources(for: pages)
        let extracted: MathMaterialModel
        do {
            extracted = try await engine.extract(pages: pages, preparedSources: sources, title: title, onProgress: onProgress)
        } catch ExtractionServiceError.noReadableResult {
            try Task.checkCancellation()
            let assessments = conversionAssessments(pages: pages)
            let issues = assessments.contains { $0.status != .ready } ? assessments : pages.map {
                TeacherPageReadability.afterConversion(id: $0.id, hasBodyChunks: false, processingSucceeded: false)
            }
            throw TeacherConversionRecovery(assessments: issues, partialResult: nil)
        }
        let assessments = conversionAssessments(pages: pages)
        guard assessments.contains(where: { $0.status == .ready }) else {
            throw TeacherConversionRecovery(assessments: assessments, partialResult: nil)
        }
        onProgress("Menyiapkan gaya bacaan matematika…")
        let reviewIndices = Set(pages.enumerated().filter { uncertainPageIDs.contains($0.element.id) }.map(\.offset))
        var material = try await portableMaterial(from: extracted, firstBookPage: firstBookPage,
            bookPageLabels: bookPageLabels, reviewPageIndices: reviewIndices)
        onProgress("Menyusun ringkasan materi…")
        let overview = try await overviewGenerator.generate(for: material)
        try Task.checkCancellation()
        material.overview = overview.text
        if material.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            material.title = "Tanpa judul"
        }
        try? material.markValidated()
        let run = try RunRepository().finalRun(id: try requireRunID(extracted))
        try MaterialOverviewArtifactStore().write(overview, material: material, to: run.paths.root)
        let result = TeacherExtractionResult(material: material, runID: try requireRunID(extracted),
            groupingNote: "Topik disusun mengikuti judul sumber halaman.")
        if assessments.contains(where: { $0.status != .ready }) {
            throw TeacherConversionRecovery(assessments: assessments, partialResult: result)
        }
        return result
    }

    private func conversionAssessments(pages: [MaterialImageInput]) -> [TeacherPageAssessment] {
        let enginePages = engine.lastSourcePages
        let ready = engine.lastReadyDocument
        let bodyPages = Set((ready?.chunks ?? []).filter { !MaterialTopicIndex.auxiliaryKinds.contains($0.kind) }.map(\.pageID))
        return pages.enumerated().map { index, page in
            guard enginePages.indices.contains(index) else {
                return TeacherPageReadability.afterConversion(id: page.id, hasBodyChunks: false, processingSucceeded: false)
            }
            let source = enginePages[index]
            let hasBody = bodyPages.contains(source.id)
            let checksSucceeded = source.components.contains { $0.component == "apple_vision_ocr" && $0.status == "succeeded" }
                && source.components.contains { $0.component == "layout" && $0.status == "succeeded" }
            // Missing export artifacts are a processing failure, never evidence
            // that the user's image contains no text.
            return TeacherPageReadability.afterConversion(id: page.id, hasBodyChunks: hasBody,
                processingSucceeded: ready != nil && (hasBody || checksSucceeded))
        }
    }

    private func requireRunID(_ material: MathMaterialModel) throws -> String {
        guard let id = material.extractionRunID, UUID(uuidString: id) != nil else { throw MetraMaterialError.invalidContent }
        return id
    }

    private struct ChunkProjection {
        let parts: [MetraContentPart]
        let needsCorrection: Bool
        let pageLabel: String
    }

    /// Projects the engine's exact, already-merged ClearSpeak reading into inline
    /// parts. Formula occurrences are resolved through the canonical source slices,
    /// never by guessing mathematics from OCR or asking the teacher for LaTeX.
    func portableMaterial(from material: MathMaterialModel, firstBookPage: Int?, bookPageLabels: [Int]? = nil, reviewPageIndices: Set<Int> = []) async throws -> StudyMaterial {
        let runID = try requireRunID(material)
        let run = try RunRepository().finalRun(id: runID)
        let pageIndices = Dictionary(uniqueKeysWithValues: run.document.pages.enumerated().map { ($0.element.id, $0.offset) })
        let formulas = Dictionary(uniqueKeysWithValues: run.document.pages.flatMap(\.formulas).map { ($0.id, $0) })
        let segments = Dictionary(uniqueKeysWithValues: run.document.pages.flatMap(\.blocks).flatMap(\.segments).map { ($0.id, $0) })
        let fallbacks = run.document.formulaFallbacks ?? [:]
        var variants: [String: MetraContentPart] = [:]
        var projections: [String: ChunkProjection] = [:]
        let bodyChunks = material.chunks.filter { !MaterialTopicIndex.auxiliaryKinds.contains($0.kind) }

        for chunk in bodyChunks {
            try Task.checkCancellation()
            let rawReading = ReadingPresentation.text(for: chunk)
            let reading = rawReading.isEmpty
                ? (chunk.kind == "formula" ? FormulaSpeechVerbalizer.verbalize(chunk.sourceText) : chunk.sourceText)
                : rawReading
            let pageIndex = pageIndices[chunk.pageID] ?? 0
            let label = String(bookPageLabels.flatMap { $0.indices.contains(pageIndex) ? $0[pageIndex] : nil } ?? ((firstBookPage ?? 1) + pageIndex))
            let hasFallbackPreview = chunk.formulaFallbackIDs?.isEmpty == false &&
                !(chunk.spokenPreview?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let isCollapsedUnresolvedFormula = chunk.kind == "formula" && chunk.spokenText == nil && !hasFallbackPreview

            let parts: [MetraContentPart]
            if chunk.kind == "diagram" || isCollapsedUnresolvedFormula {
                let text = reading.trimmingCharacters(in: .whitespacesAndNewlines)
                parts = text.isEmpty ? [] : [.prose(text)]
            } else {
                var rawParts: [MetraContentPart] = []
                var emitCursor = reading.startIndex
                var searchStart = reading.startIndex
                let internalFormulaIDs = Set(chunk.unresolvedFormulaIDs)
                let candidateURL = run.paths.root.appendingPathComponent(chunk.sourceReference)
                let candidate = try JSONDecoder().decode(ChunkCandidate.self, from: Data(contentsOf: candidateURL))
                for slice in candidate.sourceSlices {
                    guard let id = slice.formulaID else {
                        let segText = segments[slice.segmentID]?.text ?? ""
                        let sliceText = Self.utf16Slice(segText, range: slice.textRangeUTF16)
                        searchStart = Self.advanceAnchored(in: reading, from: searchStart, matching: sliceText)
                        continue
                    }
                    guard let formula = formulas[id], formula.coveredByFormulaIDs == nil else { continue }
                    if segments[slice.segmentID]?.readingRole == "source_choice_marker" {
                        searchStart = Self.advanceAnchored(in: reading, from: searchStart, matching: formula.sourceText)
                        continue
                    }
                    let spoken = FormulaSpeechVerbalizer.resolve(
                        spokenText: formula.spokenText,
                        fallbackText: fallbacks[id]?.readerText,
                        spokenCandidate: formula.spokenCandidate,
                        latex: formula.latex,
                        sourceText: formula.sourceText
                    )
                    guard let spoken, !spoken.isEmpty else {
                        continue
                    }
                    let relative = formula.artifacts["scalar_mathml"]
                        ?? formula.artifacts["normalized_mathml"]
                        ?? formula.artifacts["mathml"]
                    let matchRange = reading.range(of: spoken, range: searchStart..<reading.endIndex)
                        ?? reading.range(of: spoken, range: emitCursor..<reading.endIndex)
                    guard let range = matchRange, let relative else {
                        let cleanFallback = ReadingPresentation.removeReviewAnnotations(spoken, internalFormulaIDs: internalFormulaIDs)
                        searchStart = Self.advanceAnchored(in: reading, from: searchStart, matching: cleanFallback)
                        continue
                    }
                    do {
                        let part: MetraContentPart
                        if let cached = variants[id] {
                            part = cached
                        } else {
                            let url = try safeArtifact(relative, in: run.paths.root)
                            let mathML = try String(contentsOf: url, encoding: .utf8)
                            let simple = try await MathCATAdapter.shared.speak(mathML: mathML, style: "SimpleSpeak")
                            var generated = MetraContentPart(kind: .math, mathML: mathML, clearSpeak: spoken, simpleSpeak: simple.spokenText)
                            do {
                                let speakEasy = try await MathCATAdapter.shared.speak(mathML: mathML, style: "LarrysSpeakeasy")
                                generated.speakEasy = speakEasy.spokenText
                                generated.speakEasyFallbackTags = speakEasy.fallbackTags
                            } catch is CancellationError {
                                throw CancellationError()
                            } catch {
                                generated.speakEasyError = error.localizedDescription
                            }
                            part = generated
                            variants[id] = part
                        }
                        if emitCursor < range.lowerBound {
                            rawParts.append(.prose(String(reading[emitCursor..<range.lowerBound])))
                        }
                        rawParts.append(part)
                        emitCursor = range.upperBound
                        searchStart = range.upperBound
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        searchStart = range.upperBound
                    }
                }
                if emitCursor < reading.endIndex {
                    rawParts.append(.prose(String(reading[emitCursor...])))
                }
                let coalesced = Self.coalesceTextParts(rawParts)
                let fallbackText = reading.trimmingCharacters(in: .whitespacesAndNewlines)
                parts = coalesced.isEmpty ? (fallbackText.isEmpty ? [] : [.prose(fallbackText)]) : coalesced
            }
            projections[chunk.id] = ChunkProjection(parts: parts, needsCorrection: false, pageLabel: label)
        }

        let chunkByID = Dictionary(uniqueKeysWithValues: bodyChunks.map { ($0.id, $0) })
        var result = StudyMaterial(id: material.id, title: material.title, category: "Matematika", content: "", createdAt: material.createdAt)
        var orphanSuppressedIDs: [String] = []
        result.topics = material.readingTopicIndex.topics.compactMap { topic in
            let topicChunks = topic.chunkIDs.compactMap { chunkByID[$0] }
            let allRows = ReadingPresentation.rows(for: topicChunks)
            guard !allRows.isEmpty else { return nil }
            let readableRows = allRows.filter { row in
                let rowParts = row.chunks.compactMap { projections[$0.id] }.flatMap(\.parts)
                return !rowParts.isEmpty || !row.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            guard !readableRows.isEmpty else {
                orphanSuppressedIDs.append(contentsOf: allRows.flatMap { $0.chunks.map(\.id) })
                return nil
            }
            let bodyRows = readableRows.filter { !ReadingPresentation.isRepeatedHeading($0, in: topic) }
            // A heading can be the only readable text in a topic. Keep it in the
            // reading instead of dropping the topic when there's no body row.
            let visibleRows = bodyRows.isEmpty ? readableRows : bodyRows
            let visibleIDs = Set(visibleRows.map(\.id))
            let suppressedIDs = allRows
                .filter { !visibleIDs.contains($0.id) }
                .flatMap { $0.chunks.map(\.id) }
            let metraChunks: [MetraChunk] = visibleRows.enumerated().compactMap { rowIndex, row in
                let rowProjections = row.chunks.compactMap { projections[$0.id] }
                guard rowProjections.count == row.chunks.count else { return nil }
                var combined: [MetraContentPart] = []
                for projection in rowProjections where !projection.parts.isEmpty {
                    if !combined.isEmpty { combined.append(.prose(" ")) }
                    combined.append(contentsOf: projection.parts)
                }
                var parts = Self.coalesceTextParts(combined)
                if parts.isEmpty {
                    let text = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return nil }
                    parts = [.prose(text)]
                }
                let rowSourceIDs = row.chunks.map(\.id)
                let sourceIDs = rowIndex == 0 ? (suppressedIDs + rowSourceIDs) : rowSourceIDs
                return MetraChunk(
                    pageLabel: rowProjections[0].pageLabel,
                    parts: parts,
                    requiresTeacherCorrection: nil,
                    reviewNote: nil,
                    sourceChunkIDs: sourceIDs
                )
            }
            return metraChunks.isEmpty ? nil : MetraTopic(title: topic.title, chunks: metraChunks)
        }
        if !orphanSuppressedIDs.isEmpty, !result.topics.isEmpty, !result.topics[0].chunks.isEmpty {
            let existing = result.topics[0].chunks[0].sourceChunkIDs ?? []
            result.topics[0].chunks[0].sourceChunkIDs = orphanSuppressedIDs + existing
        }
        let coveredIDs = result.topics.flatMap(\.chunks).flatMap { $0.sourceChunkIDs ?? [] }
        let expectedIDs = bodyChunks.map(\.id)
        guard !result.topics.isEmpty,
              coveredIDs.count == expectedIDs.count,
              Set(coveredIDs) == Set(expectedIDs) else { throw MetraMaterialError.invalidContent }
        return result
    }

    private static func utf16Slice(_ text: String, range: [Int]?) -> String {
        guard let range, range.count == 2 else { return text }
        let ns = text as NSString
        let start = max(0, min(range[0], ns.length))
        let end = max(start, min(range[1], ns.length))
        return ns.substring(with: NSRange(location: start, length: end - start))
    }

    /// Advances `start` over characters in `reading` that match `expected` from the
    /// current position without ever scanning ahead past non-matching characters.
    private static func advanceAnchored(in reading: String, from start: String.Index, matching expected: String) -> String.Index {
        var pos = start
        var expIdx = expected.startIndex
        if pos == reading.startIndex, let first = expected.first, first.isASCII, first.isLetter {
            let upper = first.uppercased()
            if expected.count == 1 {
                if reading.hasPrefix(upper + ".") {
                    return reading.index(reading.startIndex, offsetBy: 2)
                } else if reading.hasPrefix(upper) {
                    return reading.index(after: reading.startIndex)
                }
            } else {
                let secondIdx = expected.index(after: expected.startIndex)
                if ".)".contains(expected[secondIdx]), reading.hasPrefix(upper + ".") {
                    pos = reading.index(reading.startIndex, offsetBy: 2)
                    expIdx = expected.index(after: secondIdx)
                }
            }
        }
        while expIdx < expected.endIndex {
            if expected[expIdx].isWhitespace {
                expIdx = expected.index(after: expIdx)
                continue
            }
            var candidate = pos
            while candidate < reading.endIndex && reading[candidate].isWhitespace {
                candidate = reading.index(after: candidate)
            }
            guard candidate < reading.endIndex, reading[candidate] == expected[expIdx] else { break }
            pos = reading.index(after: candidate)
            expIdx = expected.index(after: expIdx)
        }
        return pos
    }

    private static func coalesceTextParts(_ parts: [MetraContentPart]) -> [MetraContentPart] {
        var merged: [MetraContentPart] = []
        for part in parts {
            if part.kind == .text {
                let text = part.text ?? ""
                guard !text.isEmpty else { continue }
                if let lastIndex = merged.indices.last, merged[lastIndex].kind == .text {
                    merged[lastIndex].text = (merged[lastIndex].text ?? "") + text
                } else {
                    merged.append(.prose(text))
                }
            } else {
                merged.append(part)
            }
        }
        return merged
    }

    private func safeArtifact(_ relative: String, in root: URL) throws -> URL {
        guard !relative.hasPrefix("/"), !relative.split(separator: "/").contains("..") else { throw MetraMaterialError.invalidContent }
        return root.appendingPathComponent(relative)
    }
}

extension ExtractionServiceError: TeacherUserFacingError { }

#endif
