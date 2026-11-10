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

    init(viewModel: SectionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    init(
        materialTitle: String,
        sections: [MathSectionModel],
        initialSectionIndex: Int = 0,
        initialSpeechStyle: SpeechStyle = .clearSpeak
    ) {
        _viewModel = State(initialValue: SectionViewModel(
            materialTitle: materialTitle,
            sections: sections,
            initialSectionIndex: initialSectionIndex,
            initialSpeechStyle: initialSpeechStyle
        ))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(viewModel.section.title)
                        .font(.title.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($readingFocus, equals: .title)
                        .id("topic-start")

                    Text(viewModel.progress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .accessibilityFocused($readingFocus, equals: .progress)

                    VStack(alignment: .leading, spacing: 20) {
                        if viewModel.readingBlocks.isEmpty {
                            Text("Konten topik ini belum tersedia.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.readingBlocks) { block in
                                contentBlock(block)
                            }
                        }
                    }
                    .padding(.top, 24)
                    .accessibilityElement(children: .contain)

                    AssistantHintCard()
                        .padding(.top, 24)

                    SectionNavigationView(
                        hasPrevious: viewModel.hasPreviousSection,
                        hasNext: viewModel.hasNextSection,
                        onPrevious: viewModel.previousSection,
                        onNext: viewModel.nextSection
                    )
                    .padding(.top, 24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
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
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Detail Topik")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(
                        "Gaya Pembacaan",
                        selection: Binding(
                            get: { viewModel.speechStyle },
                            set: { viewModel.speechStyle = $0 }
                        )
                    ) {
                        ForEach(SpeechStyle.allCases) { speechStyle in
                            Text(speechStyle.label).tag(speechStyle)
                        }
                    }
                } label: {
                    Label("Gaya Pembacaan: \(viewModel.speechStyle.label)", systemImage: "waveform")
                }
                .accessibilityLabel("Gaya pembacaan matematika, \(viewModel.speechStyle.label)")
                .accessibilityHint("Ketuk dua kali untuk mengganti antara ClearSpeak dan SimpleSpeak")
            }
        }
        .sheet(item: $assistant, onDismiss: {
            if let lastSelectedSentenceID {
                readingFocus = .sentence(lastSelectedSentenceID)
            }
        }) { selection in
            AIAssistantView(selection: selection)
        }
        .alert("Metra Assistant belum dapat dibuka", isPresented: Binding(
            get: { selectionError != nil },
            set: { if !$0 { selectionError = nil } }
        )) {
            Button("Tutup", role: .cancel) { selectionError = nil }
        } message: {
            Text(selectionError ?? "")
        }
    }

    @ViewBuilder
    private func contentBlock(_ block: SectionReadingBlock) -> some View {
        switch block.kind {
        case .text, .analogy:
            sentences(in: block)
        case .spokenMath:
            SectionHighlightCard(title: "Notasi Matematika", symbol: "function", tint: .indigo) {
                sentences(in: block)
            }
        case .visual:
            SectionHighlightCard(title: "Visual Matematika", symbol: "chart.xyaxis.line", tint: .blue) {
                sentences(in: block)
            }
        }
    }

    private func sentences(in block: SectionReadingBlock, spacing: CGFloat = 16) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
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
            selectionError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SectionView(materialTitle: "", sections: SectionViewModel.sampleSections)
    }
}

