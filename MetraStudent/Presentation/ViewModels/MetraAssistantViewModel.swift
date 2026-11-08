import Foundation
import Observation

@MainActor
@Observable
final class MetraAssistantViewModel {
    enum Phase: Equatable {
        case idle, requestingPermissions, recording, transcribing, thinking
    }

    private(set) var phase = Phase.idle
    private(set) var permissionsGranted = false
    private(set) var question = ""
    private(set) var answer: String?
    private(set) var errorMessage: String?
    private(set) var availabilityMessage: String?
    let selection: MetraAssistantSelection
    private let capture: any MetraVoiceCapturing
    private let model: FoundationMetraAssistantModel
    private var work: Task<Void, Never>?
    private var recordingLimit: Task<Void, Never>?
    private var requestID = UUID()

    init(
        selection: MetraAssistantSelection,
        capture: (any MetraVoiceCapturing)? = nil,
        model: FoundationMetraAssistantModel? = nil
    ) {
        self.selection = selection
        self.capture = capture ?? MetraSpeechCapture()
        self.model = model ?? FoundationMetraAssistantModel()
        refreshAvailability()
    }

    var canAsk: Bool {
        switch phase {
        case .idle: availabilityMessage == nil
        case .recording: true
        case .requestingPermissions, .transcribing, .thinking: false
        }
    }

    func ask() {
        guard canAsk else { return }
        if phase == .recording {
            finishRecording()
        } else if permissionsGranted {
            beginRecording()
        } else {
            requestPermissionsAndRecord()
        }
    }

    var status: String {
        switch phase {
        case .idle: return "Siap menerima pertanyaan"
        case .requestingPermissions: return "Menyiapkan izin mikrofon dan pengenalan suara"
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
        phase = .requestingPermissions
        let id = requestID
        work = Task { [weak self] in
            guard let self else { return }
            do {
                try await capture.requestPermissions()
                try Task.checkCancellation()
                guard requestID == id else { return }
                permissionsGranted = true
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
                guard !trimmed.isEmpty else { throw MetraAssistantFailure.message("Belum ada ucapan yang dikenali. Rekam ulang pertanyaanmu.") }
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
        cancel()
        errorMessage = "Aktivitas suara dihentikan karena ada interupsi. Rekam ulang saat kamu siap."
    }

    private func fail(_ error: Error) {
        if let failure = error as? MetraAssistantFailure, case .permissionDenied = failure {
            permissionsGranted = false
        }
        capture.cancel()
        recordingLimit?.cancel()
        recordingLimit = nil
        phase = .idle
        errorMessage = (error as? LocalizedError)?.errorDescription ?? "Terjadi kendala. Coba lagi."
    }
}
