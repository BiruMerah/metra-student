//
//  AddDocumentMenu.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct AddDocumentMenu: View {
    let isEnabled: Bool
    let onPickPhoto: () -> Void
    let onPickPDF: () -> Void

    var body: some View {
        Menu {
            Button("Pilih dari Galeri", systemImage: "photo", action: onPickPhoto)
            Button("Pilih PDF", systemImage: "doc", action: onPickPDF)
        } label: {
            Label("Tambah Dokumen", systemImage: "plus")
        }
        .disabled(!isEnabled)
        .accessibilityHint("Pilih foto dari galeri atau berkas PDF")
    }
}

#Preview {
    AddDocumentMenu(isEnabled: true, onPickPhoto: {}, onPickPDF: {})
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderedProminent)
}
