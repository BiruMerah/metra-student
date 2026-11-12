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
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "folder.fill.badge.person.crop")
                    .font(.title2)
                    .foregroundStyle(AppColor.brand)
                    .frame(width: 40, height: 40)
                    .background(AppColor.brandSubtle, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 3) {
                    IndonesianSpeech.text(channel.name)
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    IndonesianSpeech.text("Guru: \(channel.createdBy)")
                        .font(AppTypography.supporting)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(IndonesianSpeech.text("Kelas \(channel.name). Guru: \(channel.createdBy)."))
            
            Spacer(minLength: 8)
            
            if let onLeave {
                Button(role: .destructive, action: onLeave) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        IndonesianSpeech.text("Keluar")
                    }
                    .font(AppTypography.supportingEmphasis)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColor.danger.opacity(0.12), in: Capsule())
                    .foregroundStyle(AppColor.danger)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(IndonesianSpeech.text("Keluar dari kelas \(channel.name)"))
                .accessibilityHint(IndonesianSpeech.text("Keluar dari kelas ini."))
            }
        }
        .padding(.vertical, 4)
    }
}
