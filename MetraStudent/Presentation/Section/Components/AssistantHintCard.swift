//
//  AssistantHintCard.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct AssistantHintCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Petunjuk Metra Assistant")
                    .font(.subheadline.weight(.semibold))
                Text("Ketuk dua kali pada kalimat mana pun untuk membuka Metra Assistant dan meminta ringkasan atau penjelasan.")
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
        .accessibilityLabel("Petunjuk Metra Assistant. Ketuk dua kali pada kalimat mana pun untuk membuka Metra Assistant dan meminta ringkasan atau penjelasan.")
    }
}

#Preview {
    AssistantHintCard()
        .padding()
}
