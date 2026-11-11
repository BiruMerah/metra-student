//
//  StatusBanner.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct StatusBanner: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemImage, tint: tint)
            IndonesianSpeech.text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .listRowBackground(TintedRowBackground(tint: tint))
    }
}

#Preview {
    List {
        StatusBanner(message: "“Foto 8 Nov” sudah tersimpan.", systemImage: "checkmark.circle.fill", tint: .green)
        StatusBanner(message: "Fitur AI belum tersedia di perangkat ini.", systemImage: "exclamationmark.triangle.fill", tint: .orange)
    }
    .listStyle(.insetGrouped)
}
