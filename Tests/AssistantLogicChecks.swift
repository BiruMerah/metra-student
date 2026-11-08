import Foundation
import FoundationModels

@main
@MainActor
struct AssistantLogicChecks {
    private static let reply = "Volume diperoleh dengan mengalikan panjang, lebar, dan tinggi."
    private static let question = "Mengapa pangkat tiga?"
    private static let english = "The volume of a cube is calculated by multiplying its length, width, and height."

    static func main() async throws {
        let selection = try selectionsFromTopicReader()
        try await directQuestionAndAskAgain(selection)
        try await unavailableModelAndDeniedPermission(selection)
        try await lateResultsAreIgnored(selection)
        try await languageErrorsAndRetry(selection)
        print("All Metra Assistant Method 3 checks passed.")
    }

    private static func selectionsFromTopicReader() throws -> MetraAssistantSelection {
        let materialTitle = "Persamaan Linear Satu Variabel"
        let reader = TopicViewModel(materialTitle: materialTitle, topics: TopicViewModel.sampleTopics)
        var ids = Set<String>()
        var first: MetraAssistantSelection?
        repeat {
            let sentences = reader.readingBlocks.flatMap(\.sentences)
            for sentence in sentences {
                let selected = try reader.assistantSelection(sentenceID: sentence.id)
                try expect(ids.insert(selected.id).inserted, "Selection ID collides with another sentence")
                try expect(selected.sentence == sentence.text, "The selected sentence changed")
                try expect(selected.materialTitle == materialTitle, "The material title is missing")
                try expect(selected.topicTitle == reader.topic.title, "The topic title is wrong")
                try expect(selected.supportingText == sentences.map(\.text).joined(separator: "\n"), "Context must include the current topic in order")
                first = first ?? selected
            }
            guard reader.hasNextTopic else { break }
            reader.nextTopic()
        } while true

        do {
            _ = try reader.assistantSelection(sentenceID: "missing")
            throw CheckFailure("A missing sentence was accepted")
        } catch is MetraAssistantFailure {}

        return try first.unwrap("No sample sentences were exercised")
    }

    private static func directQuestionAndAskAgain(_ selection: MetraAssistantSelection) async throws {
        let capture = CaptureStub()
        let generator = GeneratorStub([reply, reply])
        let controller = makeController(selection, capture, generator)

        controller.ask()
        try await until { controller.phase == .recording }
        try expect(capture.permissionRequests == 1 && capture.locales == ["id-ID"], "The first ask should authorize and record in Indonesian")

        controller.ask()
        controller.ask()
        try await until { capture.transcription != nil }
        try expect(capture.finishCount == 1 && generator.requests.isEmpty, "Only the final transcript should submit, exactly once")
        capture.resolve(" \(question) ")
        try await until { controller.answer != nil }
        try expect(controller.question == question && controller.answer == reply, "The question and answer must both be visible")
        try expect(generator.requests.count == 1, "One question should generate one answer")
        try expect(controller.phase == .idle && controller.canAsk, "An answer should immediately allow another question")
        let request = generator.requests[0]
        for value in [selection.sentence, selection.supportingText, selection.topicTitle, selection.materialTitle, question] {
            try expect(request.prompt.contains(value), "The original question or topic context is missing")
        }
        try expect(request.instructions.contains("bahasa Indonesia"), "Model instructions must request Indonesian")

        controller.ask()
        try expect(controller.phase == .recording && controller.answer == nil && controller.question.isEmpty,
                   "Asking again must start a fresh recording and clear the previous result")
        controller.ask()
        try await until { capture.transcription != nil }
        let nextQuestion = "Bagaimana menghitung volume kubus?"
        capture.resolve(nextQuestion)
        try await until { controller.answer != nil }
        try expect(controller.question == nextQuestion && controller.answer == reply, "The next result must pair with the new question")
        try expect(capture.permissionRequests == 1 && generator.requests.count == 2 && controller.canAsk,
                   "The second answer should allow another question without requesting permission again")
    }

    private static func unavailableModelAndDeniedPermission(_ selection: MetraAssistantSelection) async throws {
        let capture = CaptureStub()
        let generator = GeneratorStub([reply])
        generator.availabilityMessage = "Model belum siap."
        let controller = makeController(selection, capture, generator)
        controller.ask()
        try expect(!controller.canAsk && capture.permissionRequests == 0, "An unavailable model must block recording")

        generator.availabilityMessage = nil
        controller.refreshAvailability()
        capture.permissionFailure = MetraAssistantFailure.permissionDenied("Mikrofon ditolak.")
        controller.ask()
        try await until { controller.errorMessage != nil }
        try expect(!controller.permissionsGranted && capture.locales.isEmpty && generator.requests.isEmpty, "Denied permission must leave recording idle")
    }

    private static func lateResultsAreIgnored(_ selection: MetraAssistantSelection) async throws {
        let capture = CaptureStub()
        let generator = GeneratorStub([])
        let controller = makeController(selection, capture, generator)

        controller.ask()
        try await until { controller.phase == .recording }
        controller.ask()
        try await until { capture.transcription != nil }
        controller.interrupt()
        capture.resolve(question)
        await settle()
        try expect(generator.requests.isEmpty && controller.errorMessage != nil, "An interrupted transcript must never reach the model")

        try await submit(controller, capture)
        try await until { generator.response != nil }
        controller.cancel()
        generator.resolve(reply)
        await settle()
        try expect(controller.phase == .idle && controller.answer == nil, "A cancelled answer must never appear")
    }

    private static func languageErrorsAndRetry(_ selection: MetraAssistantSelection) async throws {
        let generator = GeneratorStub([english, reply])
        let answer = try await FoundationMetraAssistantModel(generator: generator).answer(question: question, selection: selection)
        try expect(answer == reply && generator.requests.count == 2, "A confidently foreign result must be retried once")

        let repeated = GeneratorStub([english, english])
        do {
            _ = try await FoundationMetraAssistantModel(generator: repeated).answer(question: question, selection: selection)
            throw CheckFailure("A second foreign answer was accepted")
        } catch is MetraAssistantFailure {}
        try expect(repeated.requests.count == 2, "Language retry must be bounded")

        let unsupported = GeneratorStub([])
        unsupported.failure = LanguageModelError.unsupportedLanguageOrLocale(.init(
            languageCode: .init("id"), debugDescription: "Indonesian rejected by runtime"
        ))
        do {
            _ = try await FoundationMetraAssistantModel(generator: unsupported).answer(question: question, selection: selection)
            throw CheckFailure("Runtime language rejection was accepted")
        } catch let failure as MetraAssistantFailure {
            try expect(failure.localizedDescription.contains("menolak permintaan bahasa Indonesia"), "Runtime language rejection must be explained")
        }
        try expect(unsupported.requests.count == 1, "A runtime language error must not switch to a translation workflow")
    }

    private static func submit(_ controller: MetraAssistantViewModel, _ capture: CaptureStub) async throws {
        controller.ask()
        try await until { controller.phase == .recording }
        controller.ask()
        try await until { capture.transcription != nil }
        capture.resolve(question)
    }

    private static func makeController(
        _ selection: MetraAssistantSelection,
        _ capture: CaptureStub,
        _ generator: GeneratorStub
    ) -> MetraAssistantViewModel {
        MetraAssistantViewModel(
            selection: selection,
            capture: capture,
            model: FoundationMetraAssistantModel(generator: generator)
        )
    }

    private static func until(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition() {
            try expect(ContinuousClock.now < deadline, "Timed out waiting for assistant state")
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    private static func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckFailure(message) }
    }
}

private struct CheckFailure: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

private extension Optional {
    func unwrap(_ message: String) throws -> Wrapped {
        guard let self else { throw CheckFailure(message) }
        return self
    }
}

@MainActor
private final class CaptureStub: MetraVoiceCapturing {
    var permissionRequests = 0
    var permissionFailure: MetraAssistantFailure?
    var locales: [String] = []
    var finishCount = 0
    var transcription: CheckedContinuation<String, Never>?

    func requestPermissions() async throws {
        permissionRequests += 1
        if let permissionFailure { throw permissionFailure }
    }

    func start(localeIdentifier: String) throws { locales.append(localeIdentifier) }

    func finish() async throws -> String {
        finishCount += 1
        return await withCheckedContinuation { transcription = $0 }
    }

    func cancel() {}

    func resolve(_ text: String) {
        let continuation = transcription
        transcription = nil
        continuation?.resume(returning: text)
    }
}

@MainActor
private final class GeneratorStub: MetraAssistantGenerating {
    var availabilityMessage: String?
    var failure: LanguageModelError?
    var requests: [(instructions: String, prompt: String)] = []
    var response: CheckedContinuation<String, Never>?
    private var answers: [String]

    init(_ answers: [String]) { self.answers = answers }

    func respond(instructions: String, prompt: String) async throws -> String {
        requests.append((instructions, prompt))
        if let failure { throw failure }
        if !answers.isEmpty { return answers.removeFirst() }
        return await withCheckedContinuation { response = $0 }
    }

    func resolve(_ text: String) {
        let continuation = response
        response = nil
        continuation?.resume(returning: text)
    }
}
