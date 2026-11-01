//
//  AIAssistantPipeline.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 01/11/26.
//

import Foundation

@MainActor
final class AIAssistantPipeline: AssistantProvidingProtocol {
    private let assistantTranslator: any AssistantTranslatingProtocol
    private let model: any AssistantGeneratingProtocol
    var availabilityMessage: String? { model.availabilityMessage }
    
    init(assistantTranslator: any AssistantTranslatingProtocol, model: (any AssistantGeneratingProtocol)? = nil) {
        self.assistantTranslator = assistantTranslator
        self.model = model ?? FoundationModel()
    }
    
    func result(
        action: MetraAssistantAction,
        selection: MetraAssistantSelection,
        progress: @escaping @MainActor (MetraAssistantProgress) -> Void
    ) async throws -> MetraAssistantResult {
        if let message = availabilityMessage { throw MetraAssistantFailure.message(message) }
        try Task.checkCancellation()
        let source = selection.sourceSentences(for: action)
        let requiresTranslation = model.outputLanguage != "id"
        let modelInput: [String]
        if requiresTranslation {
            progress(.translatingSource)
            modelInput = try await assistantTranslator.translate(source, from: "id", to: "en")
        } else {
            modelInput = source
        }
        try Task.checkCancellation()
        guard modelInput.count == source.count, !modelInput.isEmpty,
              modelInput.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw MetraAssistantFailure.message("Materi belum lengkap untuk diproses. Silakan coba lagi.")
        }
        
        for attempt in 0..<3 {
            progress(.generating)
            let draft = try await model.generate(action: action, sentences: modelInput, extraBrief: attempt > 0)
            try Task.checkCancellation()
            let output: [String]
            if requiresTranslation {
                progress(.translatingResult)
                output = try await assistantTranslator.translate(draft, from: "en", to: "id")
            } else {
                output = draft
            }
            try Task.checkCancellation()
            guard output.count == draft.count else {
                throw MetraAssistantFailure.message("Terjemahan hasil belum lengkap. Silakan coba lagi.")
            }
            do {
                guard MetraMathGuard.preservesUnits(points: output, source: source) else {
                    throw MetraAssistantFailure.message("Satuan dalam jawaban belum sesuai materi. Silakan coba lagi.")
                }
                // Enforce limits on the FINAL Indonesian text, including spaces.
                // Never truncate an explanation, which could change its mathematical meaning.
                return try MetraAssistantResult.validated(action: action, points: output)
            } catch {
                if attempt == 2 { throw error }
            }
        }
        throw MetraAssistantFailure.message("Jawaban belum berhasil dibuat. Silakan coba lagi.")
    }
    
    func cancel() { assistantTranslator.cancel() }
}

