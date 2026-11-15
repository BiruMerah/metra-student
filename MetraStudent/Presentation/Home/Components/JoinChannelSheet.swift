//
//  JoinChannelSheet.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct JoinChannelSheet: View {
    @Binding var isPresented: Bool
    @Binding var errorMessage: String?
    let isLoading: Bool
    let onJoin: (String) async -> Bool
    
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @AccessibilityFocusState(for: .voiceOver) private var isTitleFocused: Bool
    @State private var joinChannelCodeInput: String = ""

    private var isCodeIncomplete: Bool {
        joinChannelCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).count < 6
    }

    private var joinButtonAccessibilityHint: String {
        !isLoading && isCodeIncomplete ? "Kode yang dimasukkan belum 6 karakter" : ""
    }
    
    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
                .accessibilityElement(children: .contain)
                .accessibilitySortPriority(1)

            Form {
                Section {
                    TextField("Masukkan enam karakter kode undangan dari Guru", text: $joinChannelCodeInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .font(AppTypography.accessCode)
                        .accessibilityLabel(IndonesianSpeech.text("Kode undangan kelas"))
                    
                    Button {
                        let codeToJoin = joinChannelCodeInput
                        Task {
                            let success = await onJoin(codeToJoin)
                            if success {
                                joinChannelCodeInput = ""
                                isPresented = false
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .padding(.trailing, 4)
                                    .accessibilityHidden(true)
                            }
                            IndonesianSpeech.text(isLoading ? "Sedang bergabung…" : "Gabung")
                                .font(AppTypography.headline)
                            Spacer()
                        }
                    }
                    .disabled(isCodeIncomplete || isLoading)
                    .accessibilityHint(IndonesianSpeech.text(joinButtonAccessibilityHint))
                } header: {
                    IndonesianSpeech.text("Kode undangan kelas")
                }
            }
            .contentMargins(.top, 0, for: .scrollContent)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .alert(IndonesianSpeech.text("Belum bisa bergabung"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(indonesian: "Tutup", role: .cancel) { errorMessage = nil }
        } message: {
            IndonesianSpeech.text(errorMessage ?? "")
        }
        .accessibilityDefaultFocus($isTitleFocused, true)
        .accessibilityAction(.escape) { isPresented = false }
        .presentationDetents([.medium])
        .sensoryFeedbackOnAppear()
        .task {
            guard voiceOver else { return }
            // Wait for the sheet presentation transition before falling back to explicit focus.
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            guard !isTitleFocused else { return }
            isTitleFocused = true
        }
    }

    private var sheetHeader: some View {
        HStack(spacing: AppSize.Spacing.small) {
            cancelButton
                .layoutPriority(1)
                .accessibilitySortPriority(1)

            Spacer(minLength: 0)

            sheetTitle
                .accessibilitySortPriority(2)

            Spacer(minLength: 0)

            cancelButton
                .hidden()
                .disabled(true)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, AppSize.Spacing.large)
        .padding(.top, AppSize.Spacing.large)
        .padding(.bottom, AppSize.Spacing.tight)
    }

    private var sheetTitle: some View {
        IndonesianSpeech.text("Formulir Gabung Kelas")
            .font(AppTypography.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($isTitleFocused)
    }

    private var cancelButton: some View {
        Button(indonesian: "Batal") {
            isPresented = false
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }
}

#Preview {
    JoinChannelSheet(isPresented: .constant(true), errorMessage: .constant(nil), isLoading: false) { _ in
        true
    }
}
