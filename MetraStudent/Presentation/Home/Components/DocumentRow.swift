//
//  DocumentRow.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct DocumentRow: View {
    let material: MathMaterialModel
    let isSelected: Bool?
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var metadata: String {
        let date = material.createdAt.formatted(.dateTime.day().month(.wide).year().locale(IndonesianSpeech.locale))
        let sectionCount = material.sections.count
        return sectionCount > 0 ? "\(date), \(sectionCount) segmen" : date
    }

    private var subtitle: String {
        material.category.isEmpty ? metadata : material.category
    }

    var body: some View {
        if let isSelected {
            rowButton
                .listRowBackground(TintedRowBackground(tint: isSelected ? AppColor.brand : .clear))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint(IndonesianSpeech.text(isSelected ? "Batalkan pilihan dokumen ini" : "Pilih dokumen ini"))
        } else {
            rowButton
                .accessibilityHint(IndonesianSpeech.text("Buka detail dokumen"))
                .contextMenu {
                    Button(indonesian: "Hapus Dokumen", systemImage: "trash", role: .destructive, action: onDelete)
                }
                .accessibilityAction(named: IndonesianSpeech.text("Hapus Dokumen"), onDelete)
        }
    }

    private var rowButton: some View {
        let isLargeText = dynamicTypeSize.isAccessibilitySize
        return Button(action: onTap) {
            HStack(spacing: AppSize.Spacing.medium) {
                if let isSelected {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? AppColor.brand : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
                if !isLargeText {
                    IconTile("doc.text", size: 36)
                }
                VStack(alignment: .leading, spacing: 2) {
                    IndonesianSpeech.text(material.title)
                        .font(AppTypography.body.weight(.medium))
                        .foregroundStyle(AppColor.heading)
                        .lineLimit(isLargeText ? nil : 2)
                    IndonesianSpeech.text(subtitle)
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppColor.secondaryText)
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
                if isSelected == nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.brand)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, AppSize.Spacing.tight)
            .frame(minHeight: AppSize.Height.documentRow)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading] + (isLargeText || isSelected != nil ? 0 : 36 + AppSize.Spacing.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(IndonesianSpeech.text(material.title))
        .accessibilityValue(IndonesianSpeech.text(
            material.category.isEmpty ? metadata : "\(material.category), \(metadata)"
        ))
    }
}

#Preview {
    let material = MathMaterialModel(title: "Bab I – Persamaan Linear Satu Variabel")
    List {
        DocumentRow(material: material, isSelected: nil, onTap: {}, onDelete: {})
        DocumentRow(material: material, isSelected: false, onTap: {}, onDelete: {})
        DocumentRow(material: material, isSelected: true, onTap: {}, onDelete: {})
    }
    .listStyle(.insetGrouped)
}
