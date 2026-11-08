import SwiftUI
#if os(iOS)
import AVFAudio
import UIKit
#endif

struct MetraAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var viewModel: MetraAssistantViewModel
    @AccessibilityFocusState(for: .voiceOver) private var focused: Focus?
    private enum Focus: Hashable { case heading, error, record, processing, answer }

    private var isRecording: Bool { viewModel.phase == .recording }
    private var isProcessing: Bool { viewModel.phase == .transcribing || viewModel.phase == .thinking }

    private var showsReadyStatus: Bool {
        viewModel.phase == .idle && viewModel.canAsk &&
            viewModel.question.isEmpty && viewModel.errorMessage == nil
    }

    private var resultFocus: Focus? {
        guard viewModel.errorMessage == nil else { return nil }
        if viewModel.answer != nil { return .answer }
        if isProcessing { return .processing }
        return nil
    }

    init(selection: MetraAssistantSelection) {
        _viewModel = State(initialValue: MetraAssistantViewModel(selection: selection))
    }

    var body: some View {
        #if os(iOS)
        sheet
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.didBecomeInactiveNotification)) { notification in
                if let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
                   context.source == .system {
                    viewModel.interrupt()
                }
            }
        #else
        sheet
        #endif
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            GeometryReader { viewport in
                content(viewportHeight: viewport.size.height)
            }
            .accessibilityElement(children: .contain)
            .accessibilitySortPriority(1)
            footer
                .accessibilityElement(children: .contain)
        }
        .sensoryFeedback(.start, trigger: isRecording) { _, recording in recording }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { focused = .heading }
        .onChange(of: viewModel.errorMessage) { _, message in
            if message != nil { focused = .error }
        }
        .onChange(of: isRecording) { _, recording in
            if recording { focused = .record }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { viewModel.interrupt() }
            if phase == .active { viewModel.refreshAvailability() }
        }
        .onDisappear { viewModel.cancel() }
        .accessibilityAction(.escape, close)
        .accessibilityAction(.magicTap, viewModel.ask)
    }

    private func content(viewportHeight: CGFloat) -> some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Metra Assistant")
                        .font(.largeTitle.bold())
                        .padding(.top, 30)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focused, equals: .heading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kalimat terpilih")
                            .font(.headline)
                            .foregroundStyle(.blue)
                        Text(viewModel.selection.sentence)
                            .font(.title3)
                            .lineSpacing(5)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityElement(children: .combine)

                    if showsReadyStatus {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Label(viewModel.status, systemImage: "mic")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                    }

                    availabilityNotice
                    errorNotice
                        .id(Focus.error)

                    if !viewModel.question.isEmpty {
                        result("Pertanyaan Anda", text: viewModel.question)
                            .accessibilityIdentifier("assistant-question")
                    }

                    if isProcessing {
                        statusRow("Memproses pertanyaan…", showsProgress: true)
                            .accessibilityFocused($focused, equals: .processing)
                            .id(Focus.processing)
                        Button("Batalkan Pertanyaan", role: .cancel) {
                            viewModel.cancel()
                            focused = .record
                        }
                        .buttonStyle(.bordered)
                    } else if viewModel.phase == .requestingPermissions || isRecording {
                        statusRow(viewModel.status, showsProgress: !isRecording)
                    }

                    if let answer = viewModel.answer {
                        result("Jawaban", text: answer)
                            .accessibilityFocused($focused, equals: .answer)
                            .accessibilityIdentifier("assistant-answer")
                            .id(Focus.answer)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding(24)
                .frame(
                    maxWidth: 680,
                    minHeight: showsReadyStatus ? viewportHeight : nil,
                    alignment: .topLeading
                )
                .frame(maxWidth: .infinity)
            }
            .onChange(of: resultFocus) { _, target in
                guard let target else { return }
                scroll.scrollTo(target, anchor: .top)
                if voiceOver { focused = target }
            }
            .onChange(of: viewModel.errorMessage) { _, error in
                if error != nil { scroll.scrollTo(Focus.error, anchor: .top) }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(action: viewModel.ask) {
                Label(isRecording ? "Hentikan Bertanya" : "Tanya Metra AI",
                      systemImage: isRecording ? "stop.fill" : "mic.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .tint(isRecording ? .red : .blue)
            .disabled(!viewModel.canAsk)
            .accessibilityHint(isRecording
                ? "Menghentikan rekaman dan memproses pertanyaan."
                : "Mulai merekam pertanyaan dalam bahasa Indonesia. Rekaman maksimal 60 detik.")
            .accessibilityIdentifier("assistant-record")
            .accessibilityFocused($focused, equals: .record)

            Button(action: close) {
                Text("Kembali ke Topik")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .accessibilityIdentifier("assistant-return-to-topic")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider().accessibilityHidden(true) }
    }

    @ViewBuilder
    private var availabilityNotice: some View {
        if let unavailable = viewModel.availabilityMessage {
            notice(unavailable, symbol: "exclamationmark.circle")
            Button("Periksa Ketersediaan Lagi") { viewModel.refreshAvailability() }
                .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var errorNotice: some View {
        if let error = viewModel.errorMessage {
            notice(error, symbol: "exclamationmark.bubble")
                .accessibilityFocused($focused, equals: .error)
            #if os(iOS)
            if !viewModel.permissionsGranted {
                Button("Buka Pengaturan Aplikasi") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            #endif
        }
    }

    private func statusRow(_ text: String, showsProgress: Bool) -> some View {
        HStack(spacing: 12) {
            if showsProgress {
                ProgressView().accessibilityHidden(true)
            } else {
                Image(systemName: isRecording ? "waveform" : "bubble.left.and.bubble.right")
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
            }
            Text(text).font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("assistant-status")
    }

    private func result(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(text)
                .font(.title3)
                .lineSpacing(5)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    private func close() {
        viewModel.cancel()
        dismiss()
    }

    private func notice(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
    }
}

#Preview("Metra Assistant") {
    MetraAssistantSheet(selection: MetraAssistantSelection(
        id: "preview-sentence",
        sentence: "Volume bangun ruang diperoleh dari tiga ukuran: panjang dikali lebar dikali tinggi.",
        topicTitle: "Kenapa Pangkat Tiga?",
        materialTitle: "Memahami Volume Kubus",
        supportingText: "V sama dengan sisi dikali sisi dikali sisi."
    ))
}
