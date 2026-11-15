//
//  SectionHighlightCard.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct SectionHighlightCard<Content: View>: View {
    let title: String
    let symbol: String
    var background = Color(.secondarySystemGroupedBackground)
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSize.Spacing.small) {
            HStack(spacing: AppSize.Spacing.small) {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
                IndonesianSpeech.text(title)
            }
            .font(AppTypography.body)
            .foregroundStyle(AppColor.secondaryText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(IndonesianSpeech.text(title))
            .accessibilityAddTraits(.isHeader)
            
            content()
        }
        .padding(AppSize.Inset.readingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .metraCard(radius: AppSize.Radius.callout, fill: background, border: AppColor.brand.opacity(0.22))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    SectionHighlightCard(
        title: "Notasi Matematika",
        symbol: "function",
        background: AppColor.brandSubtle
    ) {
        IndonesianSpeech.text("dua dikali eks sama dengan sepuluh")
            .font(AppTypography.readingBody)
    }
    .padding()
}
