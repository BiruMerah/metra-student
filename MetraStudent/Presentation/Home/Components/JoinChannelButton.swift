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
            HStack(spacing: 12) {
                if !isLargeText {
                    IconTile("person.2.badge.plus", tint: .accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gabung Channel")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Masukkan kode undangan dari guru")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 8)
                
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gabung Channel Kelas")
        .accessibilityValue("Masukkan kode undangan dari guru")
        .accessibilityHint("Ketuk dua kali untuk membuka formulir kode channel")
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
