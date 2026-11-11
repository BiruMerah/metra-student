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
            HStack(spacing: AppSize.Spacing.actions) {
                Image(systemName: "doc.badge.plus")
                    .font(.title3.weight(.semibold))
                IndonesianSpeech.text("Tambah Dokumen")
                    .font(AppTypography.headline)
            }
            .padding(.vertical, AppSize.Spacing.small)
            .padding(.horizontal, AppSize.Spacing.large)
            .frame(maxWidth: .infinity, minHeight: AppSize.Height.largeButton)
            .background(
                AppColor.brandFill,
                in: RoundedRectangle(cornerRadius: AppSize.Radius.largeButton, style: .circular)
            )
            .foregroundStyle(AppColor.onBrand)
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
