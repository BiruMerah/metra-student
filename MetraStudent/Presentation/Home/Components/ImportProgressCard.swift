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

    private var tint: Color { isCancelling ? .gray : .accentColor }
    private var statusTitle: String { isCancelling ? "Membatalkan…" : "Mengonversi dokumen" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                IconTile("sparkles", tint: tint)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion && !isCancelling)
                VStack(alignment: .leading, spacing: 2) {
                    IndonesianSpeech.text(statusTitle)
                        .font(.headline)
                        .contentTransition(.opacity)
                    IndonesianSpeech.text(progress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(reduceMotion ? nil : .easeInOut, value: progress)
                .animation(reduceMotion ? nil : .easeInOut, value: isCancelling)
            }
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
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    .disabled(isCancelling)
                    .accessibilityLabel(IndonesianSpeech.text("Batalkan penambahan dokumen"))
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(TintedRowBackground(tint: tint))
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
