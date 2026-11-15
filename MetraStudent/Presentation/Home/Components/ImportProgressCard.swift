//
//  ImportProgressCard.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct ImportProgressCard: View {
    let progress: String
    let isCancelling: Bool
    let onCancel: () -> Void
    @AccessibilityFocusState<Bool>.Binding var isStatusFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { isCancelling ? .gray : AppColor.brand }
    private var statusTitle: String { isCancelling ? "Membatalkan…" : "Mengonversi dokumen" }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSize.Spacing.medium) {
            VStack(alignment: .leading, spacing: AppSize.Spacing.tight) {
                IndonesianSpeech.text(statusTitle)
                    .font(AppTypography.headline)
                    .contentTransition(.opacity)
                IndonesianSpeech.text(progress)
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppColor.secondaryText)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(reduceMotion ? nil : .easeInOut, value: progress)
            .animation(reduceMotion ? nil : .easeInOut, value: isCancelling)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(IndonesianSpeech.text(statusTitle))
            .accessibilityValue(IndonesianSpeech.text(progress))
            .accessibilityFocused($isStatusFocused)
            .task(id: progress) {
                guard isStatusFocused else { return }
                do { try await Task.sleep(for: .milliseconds(600)) }
                catch { return }
                guard isStatusFocused else { return }
                IndonesianSpeech.announce(progress)
            }

            IndeterminateProgressBar(tint: tint, isAnimating: !reduceMotion && !isCancelling)

            HStack {
                Spacer(minLength: 0)
                Button(indonesian: "Batalkan", action: onCancel)
                    .buttonStyle(MetraActionStyle(appearance: .neutral, fullWidth: false))
                    .disabled(isCancelling)
                    .accessibilityLabel(IndonesianSpeech.text("Batalkan penambahan dokumen"))
            }
        }
        .padding(AppSize.Inset.page)
        .metraCard(radius: AppSize.Radius.assistantCard, border: .clear)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    @Previewable @AccessibilityFocusState(for: .voiceOver) var isConvertingFocused: Bool
    @Previewable @AccessibilityFocusState(for: .voiceOver) var isCancellingFocused: Bool
    List {
        ImportProgressCard(
            progress: "Membaca halaman 2 dari 5…",
            isCancelling: false,
            onCancel: {},
            isStatusFocused: $isConvertingFocused
        )
        ImportProgressCard(
            progress: "Membatalkan penambahan dokumen…",
            isCancelling: true,
            onCancel: {},
            isStatusFocused: $isCancellingFocused
        )
    }
    .listStyle(.insetGrouped)
}
