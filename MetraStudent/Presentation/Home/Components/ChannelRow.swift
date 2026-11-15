//
//  ChannelRow.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct ChannelRow: View {
    let channel: ClassroomChannelModel
    var onLeave: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: AppSize.Spacing.small) {
            VStack(alignment: .leading, spacing: AppSize.Spacing.tight) {
                IndonesianSpeech.text(channel.name)
                    .font(AppTypography.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                IndonesianSpeech.text("Guru: \(channel.createdBy)")
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(IndonesianSpeech.text("Kelas \(channel.name). Guru: \(channel.createdBy)."))
            
            Spacer(minLength: AppSize.Spacing.small)
            
            if let onLeave {
                Button(role: .destructive, action: onLeave) {
                    IndonesianSpeech.text("Keluar")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.secondaryText)
                        .padding(.horizontal, AppSize.Spacing.medium)
                        .frame(minHeight: AppSize.Height.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(IndonesianSpeech.text("Keluar dari kelas \(channel.name)"))
                .accessibilityHint(IndonesianSpeech.text("Keluar dari kelas ini."))
            }
        }
        .padding(.vertical, AppSize.Spacing.tight)
    }
}
