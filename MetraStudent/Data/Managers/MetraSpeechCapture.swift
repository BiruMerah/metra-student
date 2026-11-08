import Foundation
import AudioToolbox
@preconcurrency import AVFAudio
@preconcurrency import Speech

/// Records while requested, then returns the final speech transcript to the caller.
@MainActor
final class MetraSpeechCapture: MetraVoiceCapturing {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var localeIdentifier = "id-ID"
    private var recognition: SpeechRecognitionJob?

    func requestPermissions() async throws {
        try Task.checkCancellation()
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else {
            throw MetraAssistantFailure.permissionDenied("Izin pengenalan suara belum diberikan. Aktifkan Pengenalan Ucapan untuk aplikasi ini di Pengaturan.")
        }
        try Task.checkCancellation()
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard microphone else {
            throw MetraAssistantFailure.permissionDenied("Izin mikrofon belum diberikan. Aktifkan Mikrofon untuk aplikasi ini di Pengaturan.")
        }
    }

    func start(localeIdentifier: String) throws {
        cancel()
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVAudioApplication.shared.recordPermission == .granted else {
            throw MetraAssistantFailure.permissionDenied("Izin mikrofon atau pengenalan suara berubah. Aktifkan kembali di Pengaturan.")
        }
        let locale = Locale(identifier: localeIdentifier)
        guard SFSpeechRecognizer.supportedLocales().contains(where: {
            $0.language.languageCode == locale.language.languageCode && $0.region == locale.region
        }) else {
            throw MetraAssistantFailure.message("Pengenalan suara bahasa Indonesia belum didukung di perangkat ini.")
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw MetraAssistantFailure.message("Pengenalan suara untuk bahasa ini sedang tidak tersedia. Periksa koneksi lalu coba lagi.")
        }
        self.localeIdentifier = localeIdentifier
        #if os(iOS)
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audio.setActive(true)
        #endif
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("question-\(UUID().uuidString).m4a")
        recordingURL = url
        do {
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            self.recorder = recorder
            guard recorder.prepareToRecord(), recorder.record() else {
                throw MetraAssistantFailure.message("Mikrofon belum bisa merekam. Coba lagi.")
            }
        } catch {
            cancel()
            throw error
        }
    }

    func finish() async throws -> String {
        guard let url = recordingURL, let recorder else { throw CancellationError() }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        recordingURL = nil
        deactivateAudio()
        defer { try? FileManager.default.removeItem(at: url) }
        guard duration >= 0.3 else {
            throw MetraAssistantFailure.message("Rekaman terlalu singkat. Ucapkan pertanyaan sebelum mengakhiri rekaman.")
        }
        let job = SpeechRecognitionJob()
        recognition = job
        defer { if recognition === job { recognition = nil } }
        let result = try await job.transcribe(url: url, locale: Locale(identifier: localeIdentifier))
        try Task.checkCancellation()
        let text = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw MetraAssistantFailure.message("Belum ada ucapan yang dikenali. Coba bicara lebih dekat ke mikrofon.")
        }
        return text
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        if let url = recordingURL {
            recordingURL = nil
            deactivateAudio()
            try? FileManager.default.removeItem(at: url)
        }
        recognition?.cancel()
        recognition = nil
    }

    private func deactivateAudio() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}

@MainActor
private final class SpeechRecognitionJob {
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?
    private var timeout: Task<Void, Never>?

    func transcribe(url: URL, locale: Locale) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw MetraAssistantFailure.message("Pengenalan suara sedang tidak tersedia. Periksa koneksi dan coba lagi.")
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        // Prefer local recognition. Some locales require Apple's speech service and connectivity.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let finalText = result?.isFinal == true ? result?.bestTranscription.formattedString : nil
                let failed = error != nil
                Task { @MainActor [weak self] in
                    if let finalText {
                        self?.complete(.success(finalText))
                    } else if failed {
                        self?.complete(.failure(MetraAssistantFailure.message("Ucapan belum berhasil dikenali. Pastikan bahasa bicara sesuai, periksa koneksi, lalu rekam ulang.")))
                    }
                }
            }
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(20)) } catch { return }
                self?.complete(.failure(MetraAssistantFailure.message("Pengenalan suara terlalu lama. Periksa koneksi lalu rekam ulang.")))
            }
        }
    }

    func cancel() { complete(.failure(CancellationError())) }

    private func complete(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel()
        timeout = nil
        task?.cancel()
        task = nil
        continuation.resume(with: result)
    }
}
