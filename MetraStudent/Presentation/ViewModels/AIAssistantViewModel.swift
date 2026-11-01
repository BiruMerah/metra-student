//
//  AIAssistantViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 01/11/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class AIAssistantViewModel: Identifiable {
    let selection: MetraAssistantSelection
    let translationBridge: AIAssistantTranslationBridge
    private(set) var results: [MetraAssistantResult] = []
    private(set) var phase: MetraAssistantProgress?
    private(set) var activeAction: MetraAssistantAction?
    private(set) var errorMessage: String?
    private(set) var availabilityMessage: String?
    
    private let engine: any AssistantProvidingProtocol
    private var work: Task<Void, Never>?
    private var requestID = UUID()
    
    init(
        selection: MetraAssistantSelection,
        engine: (any AssistantProvidingProtocol)? = nil,
        engineFactory: ((any AssistantTranslatingProtocol) -> any AssistantProvidingProtocol)? = nil
    ) {
        self.selection = selection
        self.translationBridge = AIAssistantTranslationBridge()
        self.engine = engine ?? engineFactory?(AIAssistantTranslationBridge()) ?? AIAssistantPipeline(assistantTranslator: AIAssistantTranslationBridge())
        refreshAvailability()
    }
    
    var isBusy: Bool { phase != nil }
    var id: String { selection.id }
    var hasReachedRequestLimit: Bool { results.count >= MetraAssistantAction.allCases.count }
    
    var followUpAction: MetraAssistantAction? {
        guard results.count == 1 else { return nil }
        return results[0].action.alternative
    }
    
    func canRequest(_ action: MetraAssistantAction) -> Bool {
        !isBusy && !hasReachedRequestLimit && !results.contains(where: { $0.action == action })
    }
    
    var status: String {
        switch phase {
        case .translatingSource: "Menyiapkan materi…"
        case .generating: activeAction == .summarize ? "Membuat ringkasan…" : "Membuat penjelasan…"
        case .translatingResult: "Menyiapkan jawaban bahasa Indonesia…"
        case nil: "Pilih bantuan yang kamu perlukan."
        }
    }
    
    func refreshAvailability() { availabilityMessage = engine.availabilityMessage }
    
    func select(_ action: MetraAssistantAction) {
        guard canRequest(action) else { return }
        refreshAvailability()
        guard availabilityMessage == nil else { return }
        cancel()
        errorMessage = nil
        activeAction = action
        phase = .generating
        let id = requestID
        work = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await engine.result(action: action, selection: selection) { [weak self] progress in
                    guard let self, requestID == id else { return }
                    phase = progress
                }
                try Task.checkCancellation()
                guard requestID == id else { return }
                guard result.action == action else {
                    throw MetraAssistantFailure.message("Jenis jawaban belum sesuai permintaan. Silakan coba lagi.")
                }
                results.append(result)
                phase = nil
                work = nil
                
            } catch {
                guard requestID == id, !Task.isCancelled else { return }
                phase = nil
                work = nil
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Proses belum berhasil. Silakan coba lagi."
            }
        }
    }
    
    func cancel() {
        requestID = UUID()
        work?.cancel()
        work = nil
        engine.cancel()
        phase = nil
    }
}
