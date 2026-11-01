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
    let selection: AIAssistantSelection
    let translationBridge: AIAssistantTranslationBridge
    private(set) var results: [AIAssistantResult] = []
    private(set) var phase: AIAssistantProgress?
    private(set) var activeAction: AIAssistantAction?
    private(set) var errorMessage: String?
    private(set) var availabilityMessage: String?
    
    private let engine: any AssistantProvidingProtocol
    private var work: Task<Void, Never>?
    private var requestID = UUID()
    
    init(
        selection: AIAssistantSelection,
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
    var hasReachedRequestLimit: Bool { results.count >= AIAssistantAction.allCases.count }
    
    var followUpAction: AIAssistantAction? {
        guard results.count == 1 else { return nil }
        return results[0].action.alternative
    }
    
    func canRequest(_ action: AIAssistantAction) -> Bool {
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
    
    func select(_ action: AIAssistantAction) {
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
