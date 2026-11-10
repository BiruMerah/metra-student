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
        case highlight(Int)
        case sentence(String)
        case previousTopic
        case nextTopic
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.section.title)
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($readingFocus, equals: .title)

                Text(viewModel.progress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .accessibilityFocused($readingFocus, equals: .progress)

                assistantHint
                    .padding(.top, 24)

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

                topicNavigation
                    .padding(.top, 24)
                    .accessibilityElement(children: .contain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .accessibilityElement(children: .contain)
        .task {
            readingFocus = nil
            // Give VoiceOver time to find the title in the new scroll view.
            do { try await Task.sleep(for: .milliseconds(300)) }
            catch { return }
            readingFocus = .title
        }
        .id(viewModel.currentSectionIndex)
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
        .transaction {
            $0.animation = nil
            $0.disablesAnimations = true
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
            highlightBox(title: "Notasi Matematika", symbol: "function", tint: .indigo, block: block) {
                sentences(in: block)
            }
        case .visual:
            highlightBox(title: "Visual Matematika", symbol: "chart.xyaxis.line", tint: .blue, block: block) {
                sentences(in: block)
            }
        }
    }

    private func sentences(in block: SectionReadingBlock, spacing: CGFloat = 16) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(block.sentences) { sentence in
                Text(sentence.text)
                    .font(.body)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { openAssistant(sentenceID: sentence.id) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(sentence.text)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Ketuk dua kali untuk bertanya tentang kalimat ini.")
                    .accessibilityAction { openAssistant(sentenceID: sentence.id) }
                    .accessibilityFocused($readingFocus, equals: .sentence(sentence.id))
                    .accessibilityIdentifier("topic-sentence-\(sentence.id)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func openAssistant(sentenceID: String) {
        do {
            let selection = try viewModel.assistantSelection(sentenceID: sentenceID)
            lastSelectedSentenceID = sentenceID
            readingFocus = nil
            assistant = selection
        } catch {
            selectionError = error.localizedDescription
        }
    }

    private func highlightBox<Content: View>(
        title: String,
        symbol: String,
        tint: Color,
        block: SectionReadingBlock,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(.primary)
            }
            .font(.subheadline.weight(.semibold))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($readingFocus, equals: .highlight(block.id))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.4), lineWidth: 1)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }

    private var assistantHint: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Petunjuk Metra Assistant")
                    .font(.subheadline.weight(.semibold))
                Text("Ketuk dua kali pada kalimat mana pun untuk membuka Metra Assistant dan bertanya dengan suara.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Petunjuk Metra Assistant. Ketuk dua kali pada kalimat mana pun untuk membuka Metra Assistant dan bertanya dengan suara.")
    }

    private var topicNavigation: some View {
        VStack(spacing: 0) {
            Divider().accessibilityHidden(true)

            VStack(spacing: 12) {
                navigationButton(
                    title: "Segmen Selanjutnya",
                    symbol: "forward.end.fill",
                    enabled: viewModel.hasNextSection,
                    action: viewModel.nextSection
                )
                .accessibilityFocused($readingFocus, equals: .nextTopic)
                .accessibilityHidden(!viewModel.hasNextSection)

                navigationButton(
                    title: "Segmen Sebelumnya",
                    symbol: "backward.end.fill",
                    enabled: viewModel.hasPreviousSection,
                    action: viewModel.previousSection
                )
                .accessibilityFocused($readingFocus, equals: .previousTopic)
                .accessibilityHidden(!viewModel.hasPreviousSection)
            }
            .padding(.top, 16)
        }
    }

    private func navigationButton(
        title: String,
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .foregroundStyle(enabled ? Color.accentColor : Color.secondary)
                .background(Color.primary.opacity(0.06), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(SectionNavigationButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
    }

    private struct SectionNavigationButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
        }
    }
}

#Preview("Light") {
    NavigationStack {
        SectionView(materialTitle: "Persamaan Linear Satu Variabel", sections: SectionViewModel.sampleSections)
    }
}

#Preview("Dark") {
    NavigationStack {
        SectionView(materialTitle: "Persamaan Linear Satu Variabel", sections: SectionViewModel.sampleSections, initialSectionIndex: 2)
    }
    .preferredColorScheme(.dark)
}
