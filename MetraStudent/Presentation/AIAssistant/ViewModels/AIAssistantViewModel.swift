import Foundation
import Observation

@MainActor
@Observable
final class AIAssistantViewModel {
    enum Phase: Equatable {
        case idle, requestingPermissions, recording, transcribing, thinking
    }

    private(set) var phase = Phase.idle
    private(set) var permissionsGranted = false
    private(set) var needsPermissionSettings = false
    var inputText = ""
    private(set) var question = ""
    private(set) var answer: String?
    private(set) var errorMessage: String?
    private(set) var availabilityMessage: String?
    let selection: AIAssistantSelection
    private let capture: any AssistantVoiceCapturingProtocol
    private let model: FoundationModel
    private var work: Task<Void, Never>?
    private var recordingLimit: Task<Void, Never>?
    private var requestID = UUID()

    init(
        selection: AIAssistantSelection,
        capture: (any AssistantVoiceCapturingProtocol)? = nil,
        model: FoundationModel? = nil
    ) {
        self.selection = selection
        self.capture = capture ?? MetraSpeechCapture()
        self.model = model ?? FoundationModel()
        refreshAvailability()
    }

    var canRecord: Bool {
        switch phase {
        case .idle: availabilityMessage == nil
        case .recording: true
        case .requestingPermissions, .transcribing, .thinking: false
        }
    }

    var canAsk: Bool { canRecord }

    var canSubmitText: Bool {
        phase == .idle && availabilityMessage == nil &&
            !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var availabilityCanOpenSettings: Bool {
        availabilityMessage != nil && model.availabilityCanOpenSettings
    }

    func ask() {
        if phase == .recording {
            finishRecording()
        } else {
            beginVoiceQuestion()
        }
    }

    func beginVoiceQuestion() {
        guard canRecord, phase != .recording else { return }
        if permissionsGranted {
            beginRecording()
        } else {
            requestPermissionsAndRecord()
        }
    }

    func submitTypedQuestion() {
        guard canSubmitText else { return }
        let submittedQuestion = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        startAnswering(question: submittedQuestion)
    }

    var status: String {
        switch phase {
        case .idle: return "Ketik pertanyaan atau gunakan mikrofon"
        case .requestingPermissions: return "Menyiapkan mikrofon"
        case .recording: return "Mendengarkan pertanyaanmu…"
        case .transcribing: return "Mengenali ucapan…"
        case .thinking: return "Menyiapkan jawaban…"
        }
    }

    func refreshAvailability() { availabilityMessage = model.availabilityMessage }

    private func requestPermissionsAndRecord() {
        guard phase == .idle else { return }
        refreshAvailability()
        guard availabilityMessage == nil else { return }
        errorMessage = nil
        needsPermissionSettings = false
        phase = .requestingPermissions
        let id = requestID
        work = Task { [weak self] in
            guard let self else { return }
            do {
                try await capture.requestPermissions()
                try Task.checkCancellation()
                guard requestID == id else { return }
                permissionsGranted = true
                needsPermissionSettings = false
                phase = .idle
                beginRecording()
            } catch {
                guard requestID == id, !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    private func beginRecording() {
        refreshAvailability()
        guard availabilityMessage == nil else { return }
        cancel()
        errorMessage = nil
        needsPermissionSettings = false
        inputText = ""
        question = ""
        answer = nil
        do {
            try capture.start(localeIdentifier: "id-ID")
            phase = .recording
            let id = requestID
            recordingLimit = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                guard let self, requestID == id, phase == .recording else { return }
                finishRecording()
            }
        } catch { fail(error) }
    }

    // Accept only the first stop event for a recording.
    private func finishRecording() {
        guard phase == .recording else { return }
        recordingLimit?.cancel()
        recordingLimit = nil
        phase = .transcribing
        let id = requestID
        work = Task { [weak self] in
            guard let self else { return }
            do {
                let transcript = try await capture.finish()
                try Task.checkCancellation()
                guard requestID == id else { return }
                let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { throw AIAssistantFailure.message("Belum ada ucapan yang dikenali. Rekam ulang pertanyaanmu.") }
                question = trimmed
                phase = .thinking
                let response = try await model.answer(question: trimmed, selection: selection)
                try Task.checkCancellation()
                guard requestID == id else { return }
                answer = response
                phase = .idle
            } catch {
                guard requestID == id, !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    private func startAnswering(question submittedQuestion: String) {
        cancel()
        errorMessage = nil
        needsPermissionSettings = false
        inputText = ""
        question = submittedQuestion
        answer = nil
        phase = .thinking
        let id = requestID
        work = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await model.answer(question: submittedQuestion, selection: selection)
                try Task.checkCancellation()
                guard requestID == id else { return }
                answer = response
                phase = .idle
            } catch {
                guard requestID == id, !Task.isCancelled else { return }
                fail(error)
            }
        }
    }

    func cancel() {
        requestID = UUID()
        work?.cancel()
        work = nil
        recordingLimit?.cancel()
        recordingLimit = nil
        capture.cancel()
        phase = .idle
    }

    func interrupt() {
        guard phase != .idle else { return }
        let wasUsingVoice = phase == .requestingPermissions || phase == .recording || phase == .transcribing
        cancel()
        errorMessage = wasUsingVoice
            ? "Perekaman atau pemrosesan suara terhenti. Rekam ulang saat kamu siap."
            : "Pemrosesan pertanyaan terhenti. Kirim pertanyaanmu lagi saat kamu siap."
    }

    private func fail(_ error: Error) {
        if let failure = error as? AIAssistantFailure, case .permissionDenied = failure {
            permissionsGranted = false
            needsPermissionSettings = true
        } else {
            needsPermissionSettings = false
        }
        capture.cancel()
        recordingLimit?.cancel()
        recordingLimit = nil
        phase = .idle
        errorMessage = (error as? AIAssistantFailure)?.errorDescription ?? "Asisten Metra belum bisa memproses pertanyaanmu. Coba lagi."
    }
}
