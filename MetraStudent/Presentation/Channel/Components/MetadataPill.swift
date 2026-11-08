//
//  MetadataPill.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct MetadataPill: View {
    let icon: String
    let text: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
        .foregroundStyle(tint)
    }
}

#Preview {
    HStack {
        MetadataPill(icon: "icloud.fill", text: "Kuota: Bu Guru", tint: .blue)
        MetadataPill(icon: "person.2.fill", text: "25 Anggota", tint: .secondary)
        MetadataPill(icon: "doc.text.fill", text: "3 Materi", tint: .indigo)
    }
    .padding()
}
