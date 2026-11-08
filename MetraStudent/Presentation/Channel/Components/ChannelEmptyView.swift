//
//  ChannelEmptyView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct ChannelEmptyView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3.sequence.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Belum Ada Channel Kelas")
                .font(.headline)
            Text("Gabung ke channel kelas guru Anda menggunakan tombol tambah (+) di pojok kanan atas.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

#Preview {
    List {
        Section {
            ChannelEmptyView()
        }
    }
}
