//
//  JoinChannelSheet.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct JoinChannelSheet: View {
    @Binding var isPresented: Bool
    @Binding var errorMessage: String?
    let isLoading: Bool
    let onJoin: (String) async -> Bool
    
    @State private var joinChannelCodeInput: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kode kelas (contoh: MTK10A)", text: $joinChannelCodeInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .font(.headline.monospaced())
                        .accessibilityLabel(IndonesianSpeech.text("Kode undangan kelas"))
                    
                    Button {
                        let codeToJoin = joinChannelCodeInput
                        Task {
                            let success = await onJoin(codeToJoin)
                            if success {
                                joinChannelCodeInput = ""
                                isPresented = false
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .padding(.trailing, 4)
                                    .accessibilityHidden(true)
                            }
                            IndonesianSpeech.text(isLoading ? "Sedang bergabung…" : "Gabung")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(joinChannelCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                } header: {
                    IndonesianSpeech.text("Kode undangan kelas")
                } footer: {
                    IndonesianSpeech.text("Masukkan enam karakter kode undangan dari guru.")
                }
            }
            .navigationTitle(IndonesianSpeech.text("Gabung Kelas"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(indonesian: "Batal") {
                        isPresented = false
                    }
                }
            }
            .alert(IndonesianSpeech.text("Belum bisa bergabung"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(indonesian: "Tutup", role: .cancel) { errorMessage = nil }
            } message: {
                IndonesianSpeech.text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    JoinChannelSheet(isPresented: .constant(true), errorMessage: .constant(nil), isLoading: false) { _ in
        true
    }
}
