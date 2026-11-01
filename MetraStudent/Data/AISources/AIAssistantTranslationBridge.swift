//
//  AIAssistantTranslationBridge.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 01/11/26.
//

import Foundation
import Observation
import Translation

@Observable
@MainActor
final class AIAssistantTranslationBridge: AssistantTranslatingProtocol {
    private(set) var configuration: TranslationSession.Configuration?
    private var pending: Request?
    private var activeSession: TranslationSession?
    
    private struct Request {
        let id: UUID
        let texts: [String]
        let source: String
        let target: String
        let continuation: CheckedContinuation<[String], Error>
    }
    
    func translate(_ texts: [String], from source: String, to target: String) async throws -> [String] {
        try Task.checkCancellation()
        let status = await LanguageAvailability(preferredStrategy: .lowLatency).status(
            from: Locale.Language(identifier: source), to: Locale.Language(identifier: target)
        )
        try Task.checkCancellation()
        guard status != .unsupported else {
#if targetEnvironment(simulator)
            throw MetraAssistantFailure.message("Terjemahan Apple tidak tersedia di Simulator. Jalankan aplikasi di iPhone dengan Apple Intelligence untuk mendengar hasil dalam bahasa Indonesia.")
#else
            throw MetraAssistantFailure.message("Terjemahan Indonesia–Inggris belum tersedia di perangkat ini. Perbarui iOS lalu coba lagi.")
#endif
        }
        guard pending == nil else { throw MetraAssistantFailure.message("Terjemahan masih berjalan. Tunggu sebentar.") }
        guard !texts.isEmpty else { return [] }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = Request(id: id, texts: texts, source: source, target: target, continuation: continuation)
                if configuration?.source == Locale.Language(identifier: source),
                   configuration?.target == Locale.Language(identifier: target) {
                    configuration?.invalidate()
                } else {
                    configuration = TranslationSession.Configuration(
                        source: Locale.Language(identifier: source), target: Locale.Language(identifier: target),
                        preferredStrategy: .lowLatency
                    )
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(requestID: id) }
        }
    }
    
    func perform(using session: TranslationSession) async {
        guard let request = pending,
              session.sourceLanguage?.languageCode?.identifier == request.source,
              session.targetLanguage?.languageCode?.identifier == request.target else { return }
        activeSession = session
        do {
            let status = await LanguageAvailability(preferredStrategy: .lowLatency).status(
                from: Locale.Language(identifier: request.source), to: Locale.Language(identifier: request.target)
            )
            guard pending?.id == request.id else { return }
            guard status != .unsupported else {
                throw MetraAssistantFailure.message("Terjemahan Indonesia–Inggris belum tersedia di perangkat ini. Perbarui iOS dan coba lagi di iPhone yang mendukung Terjemahkan.")
            }
            try await session.prepareTranslation()
            try Task.checkCancellation()
            guard pending?.id == request.id else { return }
            let batch = request.texts.enumerated().map {
                TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset))
            }
            let responses = try await session.translations(from: batch)
            try Task.checkCancellation()
            var ordered = Array<String?>(repeating: nil, count: batch.count)
            for response in responses {
                guard response.targetLanguage.languageCode?.identifier == request.target,
                      let identifier = response.clientIdentifier, let index = Int(identifier),
                      ordered.indices.contains(index), ordered[index] == nil else {
                    throw MetraAssistantFailure.message("Terjemahan belum lengkap. Silakan coba lagi.")
                }
                ordered[index] = response.targetText
            }
            guard ordered.allSatisfy({ $0 != nil }) else {
                throw MetraAssistantFailure.message("Ada bagian materi yang belum berhasil diterjemahkan. Coba lagi.")
            }
            complete(id: request.id, result: .success(ordered.compactMap { $0 }))
        } catch is CancellationError {
            complete(id: request.id, result: .failure(CancellationError()))
        } catch let error as MetraAssistantFailure {
            complete(id: request.id, result: .failure(error))
        } catch {
            complete(id: request.id, result: .failure(MetraAssistantFailure.message(
                "Terjemahan belum selesai. Jika diminta, izinkan unduhan bahasa Indonesia dan Inggris. Periksa koneksi saat mengunduh, lalu pilih tindakan lagi."
            )))
        }
    }
    
    func cancel() {
        guard let id = pending?.id else { return }
        cancel(requestID: id)
    }
    
    private func cancel(requestID: UUID) {
        guard pending?.id == requestID else { return }
        activeSession?.cancel()
        configuration = nil
        complete(id: requestID, result: .failure(CancellationError()))
    }
    
    private func complete(id: UUID, result: Result<[String], Error>) {
        guard let request = pending, request.id == id else { return }
        pending = nil
        activeSession = nil
        request.continuation.resume(with: result)
    }
}

