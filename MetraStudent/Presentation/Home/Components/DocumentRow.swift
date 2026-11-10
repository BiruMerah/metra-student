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
        let date = material.createdAt.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "id_ID")))
        let sectionCount = material.sections.count
        return sectionCount > 0 ? "\(date) · \(sectionCount) segmen" : date
    }

    var body: some View {
        if let isSelected {
            rowButton
                .listRowBackground(TintedRowBackground(tint: isSelected ? .accentColor : .clear))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint(isSelected ? "Batalkan pilihan dokumen ini" : "Pilih dokumen ini")
        } else {
            rowButton
                .accessibilityHint("Buka detail dokumen")
                .contextMenu {
                    Button("Hapus Dokumen", systemImage: "trash", role: .destructive, action: onDelete)
                }
                .accessibilityAction(named: Text("Hapus Dokumen"), onDelete)
        }
    }

    private var rowButton: some View {
        let isLargeText = dynamicTypeSize.isAccessibilitySize
        return Button(action: onTap) {
            HStack(spacing: 12) {
                if let isSelected {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
                if !isLargeText {
                    IconTile("doc.text.fill")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(material.title)
                        .font(.headline)
                        .lineLimit(isLargeText ? nil : 2)
                    Text(metadata)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
            .padding(.vertical, 4)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(material.title))
        .accessibilityValue(Text(metadata))
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
