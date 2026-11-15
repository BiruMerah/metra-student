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
            HStack(spacing: AppSize.Spacing.medium) {
                IndonesianSpeech.text(section.title)
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppSize.Inset.page)
            .padding(.vertical, AppSize.Spacing.large)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
