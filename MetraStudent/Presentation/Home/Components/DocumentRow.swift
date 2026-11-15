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

    private var accessibilityValueText: String {
        guard material.isFromTeacher else { return metadata }
        if let channelName = material.sourceChannelName {
            return "Dari guru, \(channelName), \(metadata)"
        }
        return "Dari guru, \(metadata)"
    }

    var body: some View {
        if let isSelected {
            rowButton
                .listRowBackground(TintedRowBackground(tint: isSelected ? AppColor.brand : .clear))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint(IndonesianSpeech.text(isSelected ? "Batalkan pilihan materi ini" : "Pilih materi ini"))
        } else {
            rowButton
                .accessibilityHint(IndonesianSpeech.text("Buka detail materi"))
                .contextMenu {
                    Button(indonesian: "Hapus Materi", systemImage: "trash", role: .destructive, action: onDelete)
                }
                .accessibilityAction(named: IndonesianSpeech.text("Hapus Materi"), onDelete)
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
                    IconTile("doc.text.fill")
                }
                VStack(alignment: .leading, spacing: 2) {
                    IndonesianSpeech.text(material.title)
                        .font(AppTypography.headline)
                        .lineLimit(isLargeText ? nil : 2)
                    IndonesianSpeech.text(metadata)
                        .font(AppTypography.supporting)
                        .foregroundStyle(.secondary)
                    if material.isFromTeacher {
                        TeacherSourceBadge()
                            .padding(.top, AppSize.Spacing.tight)
                    }
                }
                Spacer(minLength: 0)
                if isSelected == nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, AppSize.Spacing.tight)
            .frame(minHeight: AppSize.Height.documentRow)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(IndonesianSpeech.text(material.title))
        .accessibilityValue(IndonesianSpeech.text(accessibilityValueText))
    }
}

#Preview {
    let teacherMaterial = MathMaterialModel(
        title: "Bab I – Persamaan Linear Satu Variabel",
        isFromTeacher: true,
        sourceChannelName: "Matematika VII-A",
        sourceTeacherName: "Bu Sari"
    )
    let localMaterial = MathMaterialModel(title: "Catatan – Teorema Pythagoras")
    List {
        DocumentRow(material: teacherMaterial, isSelected: nil, onTap: {}, onDelete: {})
        DocumentRow(material: localMaterial, isSelected: nil, onTap: {}, onDelete: {})
        DocumentRow(material: teacherMaterial, isSelected: false, onTap: {}, onDelete: {})
        DocumentRow(material: teacherMaterial, isSelected: true, onTap: {}, onDelete: {})
    }
    .listStyle(.insetGrouped)
}
