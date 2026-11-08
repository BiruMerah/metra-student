//
//  SelectionBar.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct SelectionBar: View {
    let summary: String
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(summary)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Button(role: .destructive, action: onDelete) {
                Label("Hapus Dokumen Terpilih", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canDelete)
            .accessibilityHint("Meminta konfirmasi sebelum menghapus")
        }
        .padding()
        .background(.regularMaterial)
    }
}

#Preview {
    VStack {
        Spacer()
        SelectionBar(summary: "2 dokumen dipilih", canDelete: true, onDelete: {})
    }
}
