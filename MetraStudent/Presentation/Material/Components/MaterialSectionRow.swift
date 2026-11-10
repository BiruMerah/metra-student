//
//  MaterialSectionRow.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct MaterialSectionRow: View {
    let section: MathSectionModel
    let index: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 52, height: 52)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading] + 64
        }
        .accessibilityLabel("Segmen \(index + 1), \(section.title)")
        .accessibilityHint("Buka detail topik")
    }
}

#Preview {
    List {
        Section("Topik") {
            MaterialSectionRow(
                section: MathSectionModel(title: "1. Pengenalan Persamaan Linear"),
                index: 0,
                onTap: {}
            )
            MaterialSectionRow(
                section: MathSectionModel(title: "2. Cara Penyelesaian"),
                index: 1,
                onTap: {}
            )
        }
    }
    .listStyle(.insetGrouped)
}
