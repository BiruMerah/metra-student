//
//  AddDocumentButton.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct AddDocumentButton: View {
    var isDisabled: Bool = false
    let onSelectPDF: () -> Void
    let onSelectPhoto: () -> Void
    
    var body: some View {
        Menu {
            Button {
                onSelectPDF()
            } label: {
                Label("Pilih Berkas PDF", systemImage: "doc")
            }
            
            Button {
                onSelectPhoto()
            } label: {
                Label("Pilih Foto dari Galeri", systemImage: "photo")
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.plus")
                    .font(.title3.weight(.semibold))
                Text("Tambah Dokumen")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                Color.accentColor,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(.white)
        }
        .disabled(isDisabled)
        .accessibilityLabel("Tambah Dokumen")
        .accessibilityHint("Pilih foto atau berkas PDF untuk dikonversi menjadi materi matematika bersuara")
    }
}

#Preview {
    VStack(spacing: 16) {
        AddDocumentButton(onSelectPDF: {}, onSelectPhoto: {})
        AddDocumentButton(isDisabled: true, onSelectPDF: {}, onSelectPhoto: {})
    }
    .padding()
}
