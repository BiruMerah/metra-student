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
                    .foregroundStyle(AppColor.brand)
                    .frame(width: 52, height: 52)
                    .background(AppColor.brandSubtle, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    IndonesianSpeech.text(section.title)
                        .font(AppTypography.headline)
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
        .accessibilityLabel(IndonesianSpeech.text("Segmen \(index + 1), \(section.title)"))
        .accessibilityHint(IndonesianSpeech.text("Buka detail topik"))
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
