import Foundation

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

@main
@MainActor
struct AssistantLogicChecks {
    static var checks = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw CheckFailure(description: message) }
        checks += 1
    }

    static func rejects(_ operation: () throws -> Void, _ message: String) throws {
        do { try operation() }
        catch { checks += 1; return }
        throw CheckFailure(description: message)
    }

    static func selection(_ texts: [String] = ["Eks adalah bilangan yang belum diketahui.", "Eks ditambah tiga sama dengan tujuh."]) throws -> MetraAssistantSelection {
        let sentences = texts.enumerated().map { MetraAssistantSentence(id: String($0.offset), text: $0.element) }
        return try .make(topicID: UUID(), topicTitle: "Persamaan", sentences: sentences, selectedID: sentences.last!.id)
    }

    static func main() async throws {
        try checkSelections()
        try checkOutputRules()
        try await checkPipeline()
        try await checkController()
        try await checkSessionCache()
        print("PASS: \(checks) checks — context boundaries, output limits, verbal math, translation, two-request flow, cached sessions and cancellation")
    }

    static func checkSelections() throws {
        let reader = TopicViewModel(topics: TopicViewModel.sampleTopics)
        for _ in TopicViewModel.sampleTopics.indices {
            let sentences = reader.readingBlocks.flatMap(\.sentences)
            for (index, sentence) in sentences.enumerated() {
                let selected = try reader.assistantSelection(sentenceID: sentence.id)
                try expect(selected.topicID == reader.topic.id, "Selection crossed topics")
                try expect(selected.selectedSentence == sentence.text, "Selected sentence changed")
                try expect(selected.sourceSentences(for: .summarize) == Array(sentences.prefix(index + 1)).map(\.text), "Summary includes future text or omits earlier text")
                try expect(selected.sourceSentences(for: .explain).last == sentence.text, "Explain must end at the selected sentence")
            }
            reader.nextTopic()
        }
        try rejects({ _ = try reader.assistantSelection(sentenceID: "missing") }, "Invalid sentence accepted")
        let repeated = try selection(["Kalimat sama.", "Kalimat sama.", "Kalimat terakhir."])
        try expect(repeated.sentencesThroughSelection.map(\.id) == ["0", "1", "2"], "Repeated text lost positional identity")
        let texts = ["Rusuk kubus sama panjang.", "Bagian pertama.", "Bagian kedua.", "Bagian ketiga.", "Bagian keempat.", "Panjang.", "Lebar.", "Tinggi.", "Ketiganya dikalikan.", "Rusuk kubus menentukan volumenya."]
        let retrieved = try selection(texts).sourceSentences(for: .explain)
        try expect(retrieved.first == texts.first && retrieved.last == texts.last, "Explain lost relevant older context")
        try expect(retrieved.count < texts.count, "Explain context is unbounded")
        try expect(FoundationMetraAssistantModel.groups(texts, wordBudget: 5).flatMap { $0 } == texts, "Grouping dropped source text")
    }

    static func checkOutputRules() throws {
        let point = "Eks adalah bilangan yang belum diketahui."
        let five = try MetraAssistantResult.validated(action: .summarize, points: [
            point, "Persamaan memiliki dua ruas yang sama nilainya.", "Kedua ruas harus tetap seimbang.",
            "Kurangi kedua ruas dengan tiga.", "Periksa jawaban dengan mengganti nilai eks."
        ])
        try expect(five.points.count == 5, "Five summary points must be accepted")
        try rejects({ _ = try MetraAssistantResult.validated(action: .summarize, points: [point, point]) }, "Duplicate summary points accepted")
        try rejects({ _ = try MetraAssistantResult.validated(action: .summarize, points: Array(repeating: point, count: 6)) }, "Six summary points accepted")
        try rejects({ _ = try MetraAssistantResult.validated(action: .summarize, points: []) }, "Empty summary accepted")
        try rejects({ _ = try MetraAssistantResult.validated(action: .summarize, points: [String(repeating: "panjang ", count: 25)]) }, "Noncompact summary accepted")
        let exact100 = point + String(repeating: " ", count: 100 - point.count - 6) + "Benar."
        let explanation = try MetraAssistantResult.validated(action: .explain, points: [exact100])
        try expect(explanation.points[0].count == 100, "Exactly one hundred characters must be accepted, including internal spaces")
        try rejects({ _ = try MetraAssistantResult.validated(action: .explain, points: [exact100 + "!"]) }, "One hundred and one characters accepted")
        try rejects({ _ = try MetraAssistantResult.validated(action: .explain, points: [point, point]) }, "Multiple explanation points accepted")
        for symbolic in ["x + 3 = 7", "Eks sama dengan 4.", "Sisi pangkat ³.", "Setengah adalah ½.", "Eks - tiga.", "Dua × tiga.", #"\frac{satu}{dua}"#, "Dua cm.", "Nilainya lima %.", "Benar ✅"] {
            try expect(!MetraAssistantResult.isVerbalMath(symbolic), "Symbolic output accepted: \(symbolic)")
        }
        try expect(MetraAssistantResult.isVerbalMath("Kedua ruas sama-sama dikurangi tiga."), "Ordinary Indonesian hyphen rejected")
        try rejects({ _ = try MetraAssistantResult.validated(action: .explain, points: ["The unknown value makes both sides of this equation equal."]) }, "English final answer accepted")
        try expect(!MetraMathGuard.preservesUnits(points: ["One inch."], source: ["One centimeter."]), "Unit conversion accepted")
        try expect(MetraMathGuard.preservesUnits(points: ["One centimetre."], source: ["One centimeter."]), "Equivalent unit spelling rejected")
    }

    static func checkPipeline() async throws {
        let input = try selection()
        let translator = TranslatorStub()
        let model = ModelStub()
        model.outputLanguage = "id"
        let direct = MetraAssistantPipeline(translator: translator, model: model)
        _ = try await direct.result(action: .explain, selection: input) { _ in }
        try expect(translator.calls.isEmpty, "Indonesian-capable model must not translate")
        try expect(model.inputs[0] == input.sourceSentences(for: .explain), "Direct model received the wrong prefix")

        let englishModel = ModelStub()
        englishModel.outputLanguage = "en"
        let bridge = TranslatorStub()
        let translated = MetraAssistantPipeline(translator: bridge, model: englishModel)
        _ = try await translated.result(action: .summarize, selection: input) { _ in }
        try expect(bridge.calls.map(\.source) == ["id", "en"], "Translation directions changed")
        try expect(bridge.calls[0].texts == input.sourceSentences(for: .summarize), "Translator received future context")
        try expect(bridge.calls[1].texts == englishModel.outputs[0], "Translation must process generated text only")

        let retryModel = ModelStub()
        retryModel.outputs = [[String(repeating: "panjang ", count: 20)], ["Eks adalah bilangan yang belum diketahui."]]
        let retried = MetraAssistantPipeline(translator: TranslatorStub(), model: retryModel)
        let short = try await retried.result(action: .explain, selection: input) { _ in }
        try expect(short.points == retryModel.outputs[1], "Overlong explanation was truncated or displayed")
        try expect(retryModel.briefFlags == [false, true], "Overlong answer did not request a shorter generation")

        let translatedLong = TranslatorStub()
        translatedLong.outputQueue = [[String(repeating: "panjang ", count: 20)], ["Eks adalah bilangan yang belum diketahui."]]
        let postTranslation = MetraAssistantPipeline(translator: translatedLong, model: englishModel)
        _ = try await postTranslation.result(action: .explain, selection: input) { _ in }
        try expect(englishModel.briefFlags.suffix(2) == [false, true], "Final Indonesian length was not revalidated")

        let unitTranslator = TranslatorStub()
        unitTranslator.outputQueue = [["Rusuk panjangnya satu inci."], ["Rusuk panjangnya satu sentimeter."]]
        let units = MetraAssistantPipeline(translator: unitTranslator, model: englishModel)
        let preserved = try await units.result(action: .explain, selection: selection(["Rusuk panjangnya satu sentimeter."])) { _ in }
        try expect(preserved.points == ["Rusuk panjangnya satu sentimeter."], "Translation introduced a different unit")

        let invalidModel = ModelStub()
        invalidModel.outputs = [["x = 4"]]
        do {
            _ = try await MetraAssistantPipeline(translator: TranslatorStub(), model: invalidModel).result(action: .explain, selection: input) { _ in }
            throw CheckFailure(description: "Persistently symbolic output was displayed")
        } catch is MetraAssistantFailure {
            try expect(invalidModel.briefFlags.count == 3, "Invalid output retries are not bounded")
        }

        let incomplete = TranslatorStub()
        incomplete.incomplete = true
        let neverModel = ModelStub()
        neverModel.outputLanguage = "en"
        do {
            _ = try await MetraAssistantPipeline(translator: incomplete, model: neverModel).result(action: .summarize, selection: input) { _ in }
            throw CheckFailure(description: "Incomplete translation accepted")
        } catch is MetraAssistantFailure {
            try expect(neverModel.inputs.isEmpty, "Model ran on incomplete translation")
        }
    }

    static func checkController() async throws {
        for firstAction in MetraAssistantAction.allCases {
            let engine = EngineStub()
            let controller = MetraAssistantViewModel(selection: try selection(), engine: engine)
            try expect(controller.followUpAction == nil && !controller.hasReachedRequestLimit, "Fresh sentence is already limited")
            controller.select(firstAction)
            controller.select(firstAction.alternative)
            await settle()
            try expect(engine.actions == [firstAction], "Duplicate taps started overlapping requests")
            engine.resolve()
            await settle()
            try expect(controller.results.count == 1 && !controller.isBusy, "First request did not complete")
            try expect(controller.followUpAction == firstAction.alternative, "Follow-up must be the unused action")
            try expect(!controller.canRequest(firstAction), "Completed action can be requested again")
            try expect(controller.canRequest(firstAction.alternative), "Unused action was blocked")
            controller.select(firstAction)
            await settle()
            try expect(engine.actions.count == 1, "Completed action started a new generation")

            controller.select(firstAction.alternative)
            await settle()
            engine.resolve()
            await settle()
            try expect(controller.results.map(\.action) == [firstAction, firstAction.alternative], "Follow-up replaced or reordered history")
            try expect(controller.hasReachedRequestLimit && controller.followUpAction == nil, "Third request is still offered")
            for action in MetraAssistantAction.allCases {
                try expect(!controller.canRequest(action), "Action still available after both results")
                controller.select(action)
            }
            await settle()
            try expect(engine.actions.count == 2, "More than two successful requests were made")
            controller.cancel()
            controller.select(firstAction)
            await settle()
            try expect(engine.actions.count == 2 && controller.results.count == 2, "Cancellation reset completed requests")
        }

        let engine = EngineStub()
        let controller = MetraAssistantViewModel(selection: try selection(), engine: engine)
        controller.select(.summarize)
        await settle()
        controller.cancel()
        engine.resolve()
        await settle()
        try expect(controller.results.isEmpty && !controller.isBusy, "Late cancelled result was appended")
        try expect(controller.canRequest(.summarize), "Cancelled request consumed an action")

        controller.select(.summarize)
        await settle()
        engine.resolve()
        await settle()
        engine.availabilityMessage = "Aktifkan Apple Intelligence."
        controller.select(.explain)
        await settle()
        try expect(engine.actions.count == 2, "Unavailable model started a request")
        try expect(controller.availabilityMessage != nil, "Unavailable state is not visible")
        engine.availabilityMessage = nil
        engine.failure = MetraAssistantFailure.message("Proses gagal.")
        controller.select(.explain)
        await settle()
        try expect(controller.errorMessage == "Proses gagal." && controller.results.count == 1, "Failure removed history or hid error")
        try expect(controller.canRequest(.explain) && !controller.hasReachedRequestLimit, "Failed follow-up consumed an action")
        engine.failure = nil
        controller.select(.explain)
        await settle()
        engine.resolve()
        await settle()
        try expect(controller.results.count == 2 && controller.errorMessage == nil, "Retry failed to complete the remaining action")
    }

    static func checkSessionCache() async throws {
        let reader = TopicViewModel(topics: TopicViewModel.sampleTopics)
        let sentences = reader.readingBlocks.flatMap(\.sentences)
        let engine = EngineStub()
        let first = try reader.assistantSession(sentenceID: sentences[0].id, engine: engine)
        first.select(.explain)
        await settle()
        engine.resolve()
        await settle()
        first.cancel()

        let reopened = try reader.assistantSession(sentenceID: sentences[0].id, engine: engine)
        try expect(first === reopened, "Reopening a sentence creates a new request budget")
        try expect(reopened.results.count == 1 && reopened.followUpAction == .summarize, "Reopening lost the first result or wrong follow-up")
        reopened.select(.summarize)
        await settle()
        engine.resolve()
        await settle()
        reopened.cancel()
        let completed = try reader.assistantSession(sentenceID: sentences[0].id, engine: engine)
        completed.select(.explain)
        completed.select(.summarize)
        await settle()
        try expect(completed.hasReachedRequestLimit && engine.actions.count == 2, "Reopening a completed sentence allowed another request")

        let other = try reader.assistantSession(sentenceID: sentences[1].id, engine: EngineStub())
        try expect(other !== completed && other.results.isEmpty && other.canRequest(.explain), "Different sentence shares another sentence's limit")
        reader.nextTopic()
        let nextSentence = reader.readingBlocks.flatMap(\.sentences)[0]
        let nextTopic = try reader.assistantSession(sentenceID: nextSentence.id, engine: EngineStub())
        try expect(nextTopic !== completed && nextTopic.results.isEmpty, "Same local sentence ID across topics shares a limit")
        reader.previousTopic()
        let returned = try reader.assistantSession(sentenceID: sentences[0].id, engine: engine)
        try expect(returned === completed && returned.hasReachedRequestLimit, "Moving between topics resets the sentence budget")
    }

    static func settle() async { for _ in 0..<100 { await Task.yield() } }
}

@MainActor
private final class TranslatorStub: MetraAssistantTranslating {
    struct Call { let texts: [String]; let source: String }
    var calls: [Call] = []
    var outputQueue: [[String]] = []
    var incomplete = false
    func translate(_ texts: [String], from source: String, to target: String) async throws -> [String] {
        calls.append(Call(texts: texts, source: source))
        if incomplete { return [] }
        if target == "en" { return texts.map { _ in "The unknown value makes both sides equal." } }
        if !outputQueue.isEmpty { return outputQueue.removeFirst() }
        return texts.map { _ in "Eks adalah bilangan yang belum diketahui." }
    }
    func cancel() {}
}

@MainActor
private final class ModelStub: MetraAssistantGenerating {
    var availabilityMessage: String?
    var outputLanguage = "id"
    var outputs = [["Eks adalah bilangan yang belum diketahui."]]
    var inputs: [[String]] = []
    var briefFlags: [Bool] = []
    func generate(action: MetraAssistantAction, sentences: [String], extraBrief: Bool) async throws -> [String] {
        inputs.append(sentences)
        briefFlags.append(extraBrief)
        return outputs[min(inputs.count - 1, outputs.count - 1)]
    }
}

@MainActor
private final class EngineStub: MetraAssistantProviding {
    var availabilityMessage: String?
    var actions: [MetraAssistantAction] = []
    var failure: Error?
    private var pending: CheckedContinuation<MetraAssistantResult, Never>?
    func result(action: MetraAssistantAction, selection: MetraAssistantSelection, progress: @escaping @MainActor (MetraAssistantProgress) -> Void) async throws -> MetraAssistantResult {
        actions.append(action)
        progress(.generating)
        if let failure { throw failure }
        return await withCheckedContinuation { pending = $0 }
    }
    func resolve() {
        guard let pending, let action = actions.last else { return }
        self.pending = nil
        pending.resume(returning: try! .validated(action: action, points: ["Eks adalah bilangan yang belum diketahui."]))
    }
    func cancel() { /* Deliberately allow late completion to test stale-result protection. */ }
}
