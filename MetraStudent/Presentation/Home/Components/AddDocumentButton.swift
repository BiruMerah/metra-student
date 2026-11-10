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
    var onTakePhoto: (() -> Void)?
    
    var body: some View {
        Menu {
            if let onTakePhoto {
                Button(indonesian: "Ambil Foto dengan Kamera", systemImage: "camera", action: onTakePhoto)
            }

            Button {
                onSelectPDF()
            } label: {
                Label(indonesian: "Pilih Berkas PDF", systemImage: "doc", spokenAs: "Pilih berkas pe de ef")
            }
            
            Button {
                onSelectPhoto()
            } label: {
                Label(indonesian: "Pilih Foto dari Galeri", systemImage: "photo")
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.plus")
                    .font(.title3.weight(.semibold))
                IndonesianSpeech.text("Tambah Dokumen")
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
        .accessibilityLabel(IndonesianSpeech.text("Tambah Dokumen"))
        .accessibilityHint(IndonesianSpeech.text("Buka pilihan sumber dokumen untuk dikonversi menjadi materi matematika bersuara"))
    }
}

#Preview {
    VStack(spacing: 16) {
        AddDocumentButton(onSelectPDF: {}, onSelectPhoto: {}, onTakePhoto: {})
        AddDocumentButton(isDisabled: true, onSelectPDF: {}, onSelectPhoto: {})
    }
    .padding()
}
