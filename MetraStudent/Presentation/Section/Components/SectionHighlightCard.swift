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
    var background = Color(uiColor: .secondarySystemGroupedBackground)
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSize.Spacing.medium) {
            HStack(spacing: AppSize.Spacing.small) {
                Image(systemName: symbol)
                    .foregroundStyle(AppColor.brand)
                    .accessibilityHidden(true)
                IndonesianSpeech.text(title)
                    .foregroundStyle(.primary)
            }
            .font(AppTypography.headline)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(IndonesianSpeech.text(title))
            .accessibilityAddTraits(.isHeader)
            
            content()
        }
        .padding(AppSize.Inset.readingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: AppSize.Radius.callout))
        .overlay {
            RoundedRectangle(cornerRadius: AppSize.Radius.callout)
                .strokeBorder(AppColor.brand.opacity(0.4), lineWidth: 1)
                .accessibilityHidden(true)
        }
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
