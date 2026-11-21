import SwiftUI
#if os(iOS)
import AVFAudio
import UIKit
#endif

struct AIAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var viewModel: AIAssistantViewModel
    @FocusState private var isInputFocused: Bool
    @AccessibilityFocusState(for: .voiceOver) private var focused: Focus?
    private enum Focus: Hashable { case heading, error, record, processing, answer }

    private var isRecording: Bool { viewModel.phase == .recording }
    private var isProcessing: Bool { viewModel.phase == .transcribing || viewModel.phase == .thinking }
    private var isComposerDisabled: Bool { viewModel.phase != .idle || viewModel.availabilityMessage != nil }

    private var showsReadyStatus: Bool {
        viewModel.phase == .idle && viewModel.canAsk &&
            viewModel.inputText.isEmpty && viewModel.question.isEmpty && viewModel.errorMessage == nil
    }

    private var resultFocus: Focus? {
        guard viewModel.errorMessage == nil else { return nil }
        if viewModel.answer != nil { return .answer }
        if isProcessing { return .processing }
        return nil
    }

    init(selection: AIAssistantSelection) {
        _viewModel = State(initialValue: AIAssistantViewModel(selection: selection))
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
        .presentationBackground(AppColor.background)
        .task { focused = .heading }
        .onChange(of: viewModel.errorMessage) { _, message in
            if message != nil { focused = .error }
        }
        .onChange(of: isRecording) { _, recording in
            if recording { focused = .record }
        }
        .onChange(of: isComposerDisabled) { _, disabled in
            if disabled { isInputFocused = false }
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
                    IndonesianSpeech.text("Metra Assistant", spokenAs: "Asisten Metra")
                        .font(AppTypography.screenTitle)
                        .foregroundStyle(AppColor.heading)
                        .padding(.top, 30)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focused, equals: .heading)

                    VStack(alignment: .leading, spacing: AppSize.Spacing.small) {
                        IndonesianSpeech.text("Kalimat terpilih")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColor.heading)
                        IndonesianSpeech.text(viewModel.selection.sentence)
                            .font(AppTypography.readingBody)
                    }
                    .padding(AppSize.Inset.assistantCard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.brandSubtle, in: RoundedRectangle(cornerRadius: AppSize.Radius.assistantCard))
                    .accessibilityElement(children: .combine)

                    if showsReadyStatus {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Label(indonesian: viewModel.status, systemImage: "text.bubble")
                                .font(AppTypography.supportingEmphasis)
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
                        Button(indonesian: "Batalkan Pertanyaan", role: .cancel) {
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
                            .padding(AppSize.Inset.assistantCard)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: AppSize.Radius.assistantCard)
                            )
                    }
                }
                .padding(AppSize.Inset.sheet)
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
        VStack(spacing: AppSize.Spacing.actions) {
            questionComposer

            Button(action: close) {
                IndonesianSpeech.text("Kembali ke Topik")
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("assistant-return-to-topic")
        }
        .padding(.horizontal, AppSize.Inset.sheet)
        .padding(.vertical, AppSize.Spacing.actions)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .background(AppColor.background)
        .overlay(alignment: .top) { Divider().accessibilityHidden(true) }
    }

    private var questionComposer: some View {
        HStack(alignment: .bottom, spacing: AppSize.Spacing.small) {
            TextField(
                "",
                text: $viewModel.inputText,
                prompt: IndonesianSpeech.text(isRecording ? "Mendengarkan pertanyaan…" : "Ketik pertanyaan…")
                    .foregroundStyle(AppColor.secondaryText.opacity(0.8)),
                axis: .vertical
            )
            .font(AppTypography.body)
            .lineLimit(1...4)
            .submitLabel(.send)
            .focused($isInputFocused)
            .disabled(isComposerDisabled)
            .onSubmit(viewModel.submitTypedQuestion)
            .padding(.vertical, AppSize.Spacing.small)
            .frame(maxWidth: .infinity, minHeight: AppSize.Height.tapTarget, alignment: .leading)
            .accessibilityLabel(IndonesianSpeech.text("Pertanyaan untuk Asisten Metra"))
            .accessibilityHint(IndonesianSpeech.text("Ketik pertanyaan lalu pilih Kirim, atau gunakan tombol mikrofon."))
            .accessibilityIdentifier("assistant-question-input")
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isComposerDisabled {
                            isInputFocused = true
                        }
                    }
                    .accessibilityHidden(true)
            }

            if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: viewModel.submitTypedQuestion) {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(AppColor.onBrand)
                        .frame(width: AppSize.Height.tapTarget, height: AppSize.Height.tapTarget)
                        .background(AppColor.brandFill, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSubmitText)
                .accessibilityLabel(IndonesianSpeech.text("Kirim Pertanyaan"))
                .accessibilityHint(IndonesianSpeech.text("Mengirim pertanyaan yang diketik ke Asisten Metra."))
                .accessibilityIdentifier("assistant-send")
            }

            Button(action: viewModel.ask) {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.headline)
                    .foregroundStyle(isRecording ? AppColor.onBrand : AppColor.brand)
                    .frame(width: AppSize.Height.tapTarget, height: AppSize.Height.tapTarget)
                    .background(isRecording ? AppColor.danger : AppColor.brandSubtle, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canRecord)
            .accessibilityLabel(IndonesianSpeech.text(isRecording ? "Hentikan Rekaman" : "Rekam Pertanyaan"))
            .accessibilityHint(IndonesianSpeech.text(isRecording
                ? "Menghentikan rekaman dan mengirim pertanyaan."
                : "Mulai merekam pertanyaan. Rekaman paling lama enam puluh detik."))
            .accessibilityIdentifier("assistant-record")
            .accessibilityFocused($focused, equals: .record)
        }
        .padding(.leading, AppSize.Spacing.large)
        .padding(.trailing, AppSize.Spacing.tight)
        .padding(.vertical, AppSize.Spacing.tight)
        .frame(minHeight: AppSize.Height.searchField)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: AppSize.Radius.largeButton))
        .overlay {
            RoundedRectangle(cornerRadius: AppSize.Radius.largeButton)
                .strokeBorder(Color.primary.opacity(0.12))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var availabilityNotice: some View {
        if let unavailable = viewModel.availabilityMessage {
            notice(unavailable, symbol: "exclamationmark.circle", tint: AppColor.warning)
            #if os(iOS)
            if viewModel.availabilityCanOpenSettings {
                Button(indonesian: "Buka Pengaturan") { openSettings() }
                    .buttonStyle(.borderedProminent)
            }
            #endif
            Button(indonesian: "Periksa Ketersediaan Lagi") { viewModel.refreshAvailability() }
                .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var errorNotice: some View {
        if let error = viewModel.errorMessage {
            notice(error, symbol: "exclamationmark.bubble", tint: AppColor.danger)
                .accessibilityFocused($focused, equals: .error)
            #if os(iOS)
            if viewModel.needsPermissionSettings {
                Button(indonesian: "Buka Pengaturan Aplikasi") { openSettings() }
            }
            #endif
        }
    }

    private func statusRow(_ text: String, showsProgress: Bool) -> some View {
        HStack(spacing: AppSize.Spacing.medium) {
            if showsProgress {
                ProgressView().accessibilityHidden(true)
            } else {
                Image(systemName: isRecording ? "waveform" : "bubble.left.and.bubble.right")
                    .foregroundStyle(isRecording ? AppColor.danger : AppColor.brand)
                    .accessibilityHidden(true)
            }
            IndonesianSpeech.text(text)
                .font(AppTypography.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("assistant-status")
    }

    private func result(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: AppSize.Spacing.small) {
            IndonesianSpeech.text(title)
                .font(AppTypography.headline)
            IndonesianSpeech.text(text)
                .font(AppTypography.readingBody)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    private func close() {
        viewModel.cancel()
        dismiss()
    }

    #if os(iOS)
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    #endif

    private func notice(_ text: String, symbol: String, tint: Color) -> some View {
        Label(indonesian: text, systemImage: symbol)
            .font(AppTypography.supporting)
            .padding(AppSize.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: AppSize.Radius.card))
            .accessibilityElement(children: .combine)
    }
}

#Preview("Metra Assistant") {
    AIAssistantView(selection: AIAssistantSelection(
        id: "preview-sentence",
        sentence: "Volume bangun ruang diperoleh dari tiga ukuran: panjang dikali lebar dikali tinggi.",
        topicTitle: "Kenapa Pangkat Tiga?",
        materialTitle: "Memahami Volume Kubus",
        supportingText: "V sama dengan sisi dikali sisi dikali sisi."
    ))
}
