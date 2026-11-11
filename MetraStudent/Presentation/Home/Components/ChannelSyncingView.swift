//
//  ChannelSyncingView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct ChannelSyncingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .accessibilityHidden(true)
            IndonesianSpeech.text("Menyinkronkan kelas dengan iCloud…")
                .font(AppTypography.supportingEmphasis)
                .foregroundStyle(.primary)
            IndonesianSpeech.text("Memeriksa akun dan memuat daftar kelasmu.")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#Preview {
    List {
        Section {
            ChannelSyncingView()
        }
    }
}
