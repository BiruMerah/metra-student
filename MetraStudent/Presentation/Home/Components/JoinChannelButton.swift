//
//  JoinChannelButton.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct JoinChannelButton: View {
    var isDisabled: Bool = false
    let action: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        let isLargeText = dynamicTypeSize.isAccessibilitySize
        Button(action: action) {
            HStack(spacing: AppSize.Spacing.medium) {
                if !isLargeText {
                    IconTile("person.2.badge.plus")
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    IndonesianSpeech.text("Gabung Kelas")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.heading)
                    IndonesianSpeech.text("Masukkan kode undangan dari guru")
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppColor.secondaryText)
                }
                
                Spacer(minLength: AppSize.Spacing.small)
                
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppColor.brand)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppSize.Spacing.large)
            .padding(.vertical, AppSize.Spacing.medium)
            .frame(maxWidth: .infinity, minHeight: AppSize.Height.largeButton, alignment: .leading)
            .background(
                AppColor.brandSubtle,
                in: RoundedRectangle(cornerRadius: AppSize.Radius.largeButton, style: .circular)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSize.Radius.largeButton, style: .circular)
                    .strokeBorder(AppColor.brand.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IndonesianSpeech.text("Gabung kelas"))
        .accessibilityValue(IndonesianSpeech.text("Masukkan kode undangan dari guru"))
        .accessibilityHint(IndonesianSpeech.text("Buka formulir untuk memasukkan kode undangan kelas."))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: 16) {
        JoinChannelButton(action: {})
        JoinChannelButton(isDisabled: true, action: {})
    }
    .padding()
}
