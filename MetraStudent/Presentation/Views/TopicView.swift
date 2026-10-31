import SwiftUI

struct TopicView: View {
    private enum ReadingFocus: Hashable {
        case title
        case progress
        case highlight(Int)
        case sentence(String)
        case previousTopic
        case nextTopic
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState(for: .voiceOver) private var readingFocus: ReadingFocus?
    @State private var viewModel: TopicViewModel
    @State private var assistant: MetraAssistantViewModel?
    @State private var lastSelectedSentenceID: String?
    @State private var selectionError: String?

    init(topics: [MathTopicModel], initialTopicIndex: Int = 0) {
        _viewModel = State(initialValue: TopicViewModel(
            topics: topics,
            initialTopicIndex: initialTopicIndex
        ))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(viewModel.topic.title)
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

                    assistantHint
                        .padding(.top, 24)

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
            .task(id: viewModel.topic.id) {
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
        .sheet(item: $assistant, onDismiss: {
            if let lastSelectedSentenceID {
                readingFocus = .sentence(lastSelectedSentenceID)
            }
        }) { session in
            MetraAssistantSheet(viewModel: session)
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
    private func contentBlock(_ block: TopicReadingBlock) -> some View {
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

    private func sentences(in block: TopicReadingBlock, spacing: CGFloat = 16) -> some View {
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
//                    .accessibilityHint("Ketuk dua kali untuk membuka Metra Assistant dan meringkas atau menjelaskan kalimat ini.")
                    .accessibilityAction { openAssistant(sentenceID: sentence.id) }
                    .accessibilityFocused($readingFocus, equals: .sentence(sentence.id))
                    .accessibilityIdentifier("topic-sentence-\(sentence.id)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func openAssistant(sentenceID: String) {
        do {
            let session = try viewModel.assistantSession(sentenceID: sentenceID)
            lastSelectedSentenceID = sentenceID
            readingFocus = nil
            assistant = session
        } catch {
            selectionError = error.localizedDescription
        }
    }

    private func highlightBox<Content: View>(
        title: String,
        symbol: String,
        tint: Color,
        block: TopicReadingBlock,
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
                Text("Ketuk dua kali pada kalimat mana pun untuk membuka Metra Assistant dan meminta ringkasan atau penjelasan.")
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
        .accessibilityLabel("Petunjuk Metra Assistant. Ketuk dua kali pada kalimat mana pun untuk membuka Metra Assistant dan meminta ringkasan atau penjelasan.")
    }

    private var topicNavigation: some View {
        VStack(spacing: 0) {
            Divider().accessibilityHidden(true)

            ViewThatFits(in: .horizontal) {
                if !dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: 12) {
                        topicNavigationButtons
                    }
                }

                VStack(spacing: 12) {
                    topicNavigationButtons
                }
            }
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private var topicNavigationButtons: some View {
        navigationButton(
            title: "Topik Sebelumnya",
            symbol: "backward.end.fill",
            enabled: viewModel.hasPreviousTopic,
            action: viewModel.previousTopic
        )
        .accessibilityFocused($readingFocus, equals: .previousTopic)
        .accessibilityHidden(!viewModel.hasPreviousTopic)

        navigationButton(
            title: "Topik Selanjutnya",
            symbol: "forward.end.fill",
            enabled: viewModel.hasNextTopic,
            action: viewModel.nextTopic
        )
        .accessibilityFocused($readingFocus, equals: .nextTopic)
        .accessibilityHidden(!viewModel.hasNextTopic)
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
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

#Preview("Light") {
    NavigationStack {
        TopicView(topics: TopicViewModel.sampleTopics)
    }
}

#Preview("Dark") {
    NavigationStack {
        TopicView(topics: TopicViewModel.sampleTopics, initialTopicIndex: 2)
    }
    .preferredColorScheme(.dark)
}
