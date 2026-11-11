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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                IndonesianSpeech.text("Petunjuk Asisten Metra")
                    .font(.subheadline.weight(.semibold))
                IndonesianSpeech.text(instruction)
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
        .accessibilityLabel(IndonesianSpeech.text("Petunjuk Asisten Metra. \(instruction)"))
    }
}

#Preview {
    AssistantHintCard()
        .padding()
}
