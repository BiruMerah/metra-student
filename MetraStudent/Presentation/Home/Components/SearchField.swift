//
//  SearchField.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Cari judul dokumen..."
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            TextField(placeholder, text: $text)
                .font(.body)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityLabel("Cari dokumen")
                .accessibilityHint("Ketik untuk menyaring daftar dokumen di bawah")
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hapus pencarian")
                .accessibilityHint("Ketuk dua kali untuk mengosongkan kolom pencarian")
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
    }
}

#Preview {
    List {
        SearchField(text: .constant(""))
        SearchField(text: .constant("Aljabar"))
    }
    .listStyle(.insetGrouped)
}
