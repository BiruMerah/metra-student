//
//  SectionNavigationView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct SectionNavigationView: View {
    let hasPrevious: Bool
    let hasNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            Divider().accessibilityHidden(true)

            ViewThatFits(in: .horizontal) {
                if !dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: 12) {
                        navigationButtons
                    }
                }

                VStack(spacing: 12) {
                    navigationButtons
                }
            }
            .padding(.top, 16)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var navigationButtons: some View {
        navigationButton(
            title: "Segmen Sebelumnya",
            symbol: "backward.end.fill",
            enabled: hasPrevious,
            action: onPrevious
        )
        .accessibilityHidden(!hasPrevious)

        navigationButton(
            title: "Segmen Selanjutnya",
            symbol: "forward.end.fill",
            enabled: hasNext,
            action: onNext
        )
        .accessibilityHidden(!hasNext)
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

#Preview {
    VStack(spacing: 24) {
        SectionNavigationView(hasPrevious: true, hasNext: true, onPrevious: {}, onNext: {})
        SectionNavigationView(hasPrevious: false, hasNext: true, onPrevious: {}, onNext: {})
    }
    .padding()
}
