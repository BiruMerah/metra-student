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
        HStack(alignment: .top, spacing: AppSize.Spacing.small) {
            Image(systemName: "info.circle")
                .font(.title2)
                .frame(width: AppSize.Height.tapTarget, height: AppSize.Height.tapTarget)
                .background(Color.primary.opacity(0.04), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSize.Spacing.tight) {
                IndonesianSpeech.text("Petunjuk Asisten Metra")
                    .font(AppTypography.headline)
                IndonesianSpeech.text(instruction)
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, AppSize.Spacing.actions)
        .padding(.vertical, AppSize.Inset.readingCard)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .metraCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IndonesianSpeech.text("Petunjuk Asisten Metra. \(instruction)"))
    }
}

#Preview {
    AssistantHintCard()
        .padding()
}
