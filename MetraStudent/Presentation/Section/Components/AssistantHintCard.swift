//
//  AssistantHintCard.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct AssistantHintCard: View {
    private let instruction = "Ketuk dua kali pada kalimat yang ingin kamu ringkas atau pahami."

    var body: some View {
        HStack(alignment: .top, spacing: AppSize.Spacing.medium) {
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                IndonesianSpeech.text("Petunjuk Asisten Metra")
                    .font(AppTypography.headline)
                IndonesianSpeech.text(instruction)
                    .font(AppTypography.supporting)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSize.Inset.readingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: AppSize.Radius.card)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IndonesianSpeech.text("Petunjuk Asisten Metra. \(instruction)"))
    }
}

#Preview {
    AssistantHintCard()
        .padding()
}
