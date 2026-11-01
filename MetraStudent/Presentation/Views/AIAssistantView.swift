//
//  AIAssistantView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 01/11/26.
//

import SwiftUI
import Translation

struct AIAssistantView: View {
    private enum Focus: Hashable { case selection, progress, error, result(UUID) }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AccessibilityFocusState(for: .voiceOver) private var focused: Focus?
    @State private var viewModel: AIAssistantViewModel

    init(selection: MetraAssistantSelection, engine: (any AssistantProvidingProtocol)? = nil) {
        _viewModel = State(initialValue: AIAssistantViewModel(selection: selection, engine: engine))
    }

    init(viewModel: AIAssistantViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        selectedSentence

                        if viewModel.results.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Apa yang perlu dibantu?")
                                    .font(.headline)
                                    .accessibilityAddTraits(.isHeader)

                                HStack(alignment: .top, spacing: 12) { actions }
                            }
                        }

                        if !viewModel.hasReachedRequestLimit, let message = viewModel.availabilityMessage {
                            notice(message)
                            Button("Periksa lagi") { viewModel.refreshAvailability() }
                                .buttonStyle(.bordered)
                        }

                        ForEach(viewModel.results) { result in
                            resultCard(result)
                                .id(result.id)
                        }

                        if let error = viewModel.errorMessage {
                            VStack(alignment: .leading, spacing: 12) {
                                notice(error)
                                    .accessibilityFocused($focused, equals: .error)
                                if let action = viewModel.activeAction, viewModel.canRequest(action) {
                                    Button("Coba lagi") { viewModel.select(action) }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }

                        if viewModel.isBusy {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    ProgressView().accessibilityHidden(true)
                                    Text(viewModel.status)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityFocused($focused, equals: .progress)
                                Button("Batalkan proses", role: .cancel) {
                                    viewModel.cancel()
                                    focused = .selection
                                }
                                    .buttonStyle(.bordered)
                            }
                            .id("assistant-progress")
                        } else if viewModel.errorMessage == nil, let action = viewModel.followUpAction {
                            Button(action == .summarize ? "Perlu ringkasan?" : "Perlu penjelasan?") {
                                viewModel.select(action)
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.availabilityMessage != nil)
                            .accessibilityHint("Bantuan tambahan untuk kalimat yang dipilih. Jawaban sebelumnya tetap tersedia.")
                        } else if viewModel.hasReachedRequestLimit {
                            Text("Penjelasan dan ringkasan untuk kalimat ini sudah tersedia. Silakan lanjut membaca topik.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: viewModel.results.count) { _, _ in
                    guard let result = viewModel.results.last else { return }
                    proxy.scrollTo(result.id, anchor: .top)
                    focused = .result(result.id)
                }
                .onChange(of: viewModel.isBusy) { _, busy in
                    if busy {
                        proxy.scrollTo("assistant-progress", anchor: .bottom)
                        focused = .progress
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Metra Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup", systemImage: "xmark") { close() }
                        .accessibilityLabel("Tutup Metra Assistant")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button { close() } label: {
                    Text("Lanjut membaca topik")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                    .buttonStyle(.borderedProminent)
                    .padding(16)
                    .background(.bar)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .translationTask(viewModel.translationBridge.configuration) { session in
            await viewModel.translationBridge.perform(using: session)
        }
        .task {
            viewModel.refreshAvailability()
            focused = .selection
        }
        .onChange(of: viewModel.errorMessage) { _, error in
            if error != nil { focused = .error }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { viewModel.cancel() }
            if phase == .active { viewModel.refreshAvailability() }
        }
        .onDisappear { viewModel.cancel() }
        .accessibilityAction(.escape) { close() }
    }

    private var selectedSentence: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kalimat terpilih")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.selection.selectedSentence)
                .font(.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($focused, equals: .selection)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var actions: some View {
        actionButton(.explain, detail: "Maksimal seratus karakter")
        actionButton(.summarize, detail: "Maksimal lima poin ringkas")
    }

    private func actionButton(_ action: MetraAssistantAction, detail: String) -> some View {
        Button {
            viewModel.select(action)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: action.symbol)
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canRequest(action) || viewModel.availabilityMessage != nil)
        .accessibilityLabel(action.title)
        .accessibilityHint(action == .summarize
            ? "Ringkas materi dari awal topik sampai kalimat ini, dalam maksimal lima poin matematika verbal."
            : "Jelaskan kalimat ini menggunakan konteks sebelumnya, dalam maksimal seratus karakter.")
        .accessibilityIdentifier("metra-assistant-\(action.rawValue)")
    }

    private func resultCard(_ result: MetraAssistantResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(result.action.resultTitle)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focused, equals: .result(result.id))
            ForEach(Array(result.points.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 10) {
                    if result.action == .summarize {
                        Text("•").foregroundStyle(.indigo).accessibilityHidden(true)
                    }
                    Text(point)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .font(.body)
                .lineSpacing(4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(result.action == .summarize ? "Poin \(index + 1). \(point)" : point)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("metra-assistant-result")
    }

    private func notice(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.subheadline)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
    }

    private func close() {
        viewModel.cancel()
        dismiss()
    }
}

#Preview {
    let selection = try! MetraAssistantSelection.make(
        topicID: UUID(),
        topicTitle: "Pengertian Persamaan Linear",
        sentences: [
            MetraAssistantSentence(id: "0", text: "Eks adalah bilangan yang belum diketahui."),
            MetraAssistantSentence(id: "1", text: "Eks ditambah tiga sama dengan tujuh.")
        ],
        selectedID: "1"
    )
    AIAssistantView(
        selection: selection
    )
}
