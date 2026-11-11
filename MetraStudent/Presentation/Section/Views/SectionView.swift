//
//  SectionView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct SectionView: View {
    private enum ReadingFocus: Hashable {
        case title
        case progress
        case sentence(String)
    }

    @AccessibilityFocusState(for: .voiceOver) private var readingFocus: ReadingFocus?
    @State private var viewModel: SectionViewModel
    @State private var assistant: AIAssistantSelection?
    @State private var lastSelectedSentenceID: String?
    @State private var selectionError: String?
    @State private var confirmsMaterialCompletion = false
    private let onFinish: () -> Void

    init(viewModel: SectionViewModel, onFinish: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinish = onFinish
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    IndonesianSpeech.text(viewModel.section.title)
                        .font(AppTypography.contentTitle)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($readingFocus, equals: .title)
                        .id("topic-start")

                    IndonesianSpeech.text(viewModel.progress)
                        .font(AppTypography.supporting)
                        .foregroundStyle(.secondary)
                        .padding(.top, AppSize.Spacing.small)
                        .accessibilityFocused($readingFocus, equals: .progress)

                    AssistantHintCard()
                        .padding(.top, AppSize.Spacing.large)

                    VStack(alignment: .leading, spacing: AppSize.Spacing.medium) {
                        if viewModel.readingBlocks.isEmpty {
                            IndonesianSpeech.text("Konten topik ini belum tersedia.")
                                .font(AppTypography.body)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.readingBlocks) { block in
                                contentBlock(block)
                            }
                        }
                    }
                    .padding(.top, AppSize.Spacing.large)
                    .accessibilityElement(children: .contain)

                    VStack(spacing: AppSize.Spacing.medium) {
                        Divider().accessibilityHidden(true)

                        if viewModel.hasNextSection {
                            SectionNavigationView(
                                title: "Segmen Selanjutnya",
                                symbol: "forward.end.fill",
                                action: viewModel.nextSection
                            )
                        } else {
                            SectionNavigationView(title: "Selesaikan Materi", symbol: "checkmark") {
                                confirmsMaterialCompletion = true
                            }
                        }

                        if viewModel.hasPreviousSection {
                            SectionNavigationView(
                                title: "Segmen Sebelumnya",
                                symbol: "backward.end.fill",
                                action: viewModel.previousSection
                            )
                        }
                    }
                    .padding(.top, AppSize.Spacing.large)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSize.Inset.page)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .accessibilityElement(children: .contain)
            .task(id: viewModel.section.id) {
                readingFocus = nil
                proxy.scrollTo("topic-start", anchor: .top)
                // Let the topic change settle before moving VoiceOver focus.
                do { try await Task.sleep(for: .milliseconds(300)) }
                catch { return }
                readingFocus = .title
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle(IndonesianSpeech.text("Detail Topik"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(
                        selection: Binding(
                            get: { viewModel.speechStyle },
                            set: { viewModel.speechStyle = $0 }
                        )
                    ) {
                        ForEach(SpeechStyle.allCases) { speechStyle in
                            IndonesianSpeech.text(speechStyle.localizedLabel).tag(speechStyle)
                        }
                    } label: {
                        IndonesianSpeech.text("Gaya pembacaan")
                    }
                } label: {
                    Label(indonesian: "Gaya pembacaan: \(viewModel.speechStyle.localizedLabel)", systemImage: "waveform")
                }
                .accessibilityLabel(IndonesianSpeech.text("Gaya pembacaan matematika, \(viewModel.speechStyle.localizedLabel)"))
                .accessibilityHint(IndonesianSpeech.text("Pilih bacaan terperinci atau bacaan ringkas."))
            }
        }
        .sheet(item: $assistant, onDismiss: {
            if let lastSelectedSentenceID {
                readingFocus = .sentence(lastSelectedSentenceID)
            }
        }) { selection in
            AIAssistantView(selection: selection)
        }
        .alert(IndonesianSpeech.text("Asisten Metra belum bisa dibuka"), isPresented: Binding(
            get: { selectionError != nil },
            set: { if !$0 { selectionError = nil } }
        )) {
            Button(indonesian: "Tutup", role: .cancel) { selectionError = nil }
        } message: {
            IndonesianSpeech.text(selectionError ?? "")
        }
        .alert(IndonesianSpeech.text("Selesaikan materi?"), isPresented: $confirmsMaterialCompletion) {
            Button(indonesian: "Batal", role: .cancel) {}
            Button(indonesian: "Selesaikan Materi", action: onFinish)
        } message: {
            IndonesianSpeech.text("Kamu yakin ingin mengakhiri sesi belajar materi “\(viewModel.materialTitle)”?")
        }
    }

    @ViewBuilder
    private func contentBlock(_ block: SectionReadingBlock) -> some View {
        switch block.kind {
        case .text, .analogy:
            sentences(in: block)
        case .spokenMath:
            SectionHighlightCard(title: "Notasi Matematika", symbol: "function", background: AppColor.brandSubtle) {
                sentences(in: block)
            }
        case .visual:
            SectionHighlightCard(title: "Visual Matematika", symbol: "chart.xyaxis.line") {
                sentences(in: block)
            }
        }
    }

    private func sentences(in block: SectionReadingBlock) -> some View {
        VStack(alignment: .leading, spacing: AppSize.Spacing.tight) {
            ForEach(block.sentences) { sentence in
                SectionSentenceView(sentence: sentence) {
                    openAssistant(sentenceID: sentence.id)
                }
                .accessibilityFocused($readingFocus, equals: .sentence(sentence.id))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func openAssistant(sentenceID: String) {
        do {
            let session = try viewModel.assistantSelection(sentenceID: sentenceID)
            lastSelectedSentenceID = sentenceID
            readingFocus = nil
            assistant = session
        } catch {
            selectionError = (error as? AIAssistantFailure)?.errorDescription ?? "Pilih ulang kalimat yang ingin kamu pelajari."
        }
    }
}

private extension SpeechStyle {
    var localizedLabel: String {
        switch self {
        case .clearSpeak: "Bacaan terperinci"
        case .simpleSpeak: "Bacaan ringkas"
        }
    }
}

#Preview {
    NavigationStack {
        SectionView(
            viewModel: SectionViewModel(
                materialTitle: "Persamaan Linear Satu Variabel",
                sections: SectionViewModel.sampleSections
            ),
            onFinish: {}
        )
    }
}

