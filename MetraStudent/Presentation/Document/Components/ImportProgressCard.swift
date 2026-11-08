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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { isCancelling ? .gray : .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                IconTile("sparkles", tint: tint)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion && !isCancelling)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCancelling ? "Membatalkan…" : "Mengonversi dengan AI")
                        .font(.headline)
                        .contentTransition(.opacity)
                    Text(progress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(reduceMotion ? nil : .easeInOut, value: progress)
                .animation(reduceMotion ? nil : .easeInOut, value: isCancelling)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)

            IndeterminateProgressBar(tint: tint, isAnimating: !reduceMotion && !isCancelling)

            HStack {
                Spacer(minLength: 0)
                Button("Batalkan", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    .disabled(isCancelling)
                    .accessibilityLabel(Text("Batalkan Penambahan"))
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(TintedRowBackground(tint: tint))
    }
}

#Preview {
    List {
        ImportProgressCard(progress: "Membaca halaman 2 dari 5…", isCancelling: false, onCancel: {})
        ImportProgressCard(progress: "Membatalkan penambahan dokumen…", isCancelling: true, onCancel: {})
    }
    .listStyle(.insetGrouped)
}
