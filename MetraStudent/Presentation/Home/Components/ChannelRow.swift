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
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(channel.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    Text("Guru: \(channel.createdBy)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Channel \(channel.name). Guru: \(channel.createdBy).")
            
            Spacer(minLength: 8)
            
            if let onLeave {
                Button(role: .destructive, action: onLeave) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Keluar")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12), in: Capsule())
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Keluar dari channel \(channel.name)")
                .accessibilityHint("Ketuk dua kali untuk keluar dari channel kelas ini")
            }
        }
        .padding(.vertical, 4)
    }
}
