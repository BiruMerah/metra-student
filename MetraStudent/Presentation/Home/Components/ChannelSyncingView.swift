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
            Text("Menyinkronkan data channel dari iCloud...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Text("Memeriksa status akun dan memuat daftar channel kelas Anda.")
                .font(.caption)
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
