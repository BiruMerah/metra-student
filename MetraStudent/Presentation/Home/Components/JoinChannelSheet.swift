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
                    TextField(
                        "Kode kelas (contoh: MTK10A)",
                        text: $joinChannelCodeInput,
                        prompt: Text("Kode kelas (contoh: MTK10A)").foregroundStyle(AppColor.secondaryText)
                    )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .font(AppTypography.body)
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
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
                                .font(AppTypography.body)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                    .disabled(joinChannelCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                } header: {
                    IndonesianSpeech.text("Kode undangan kelas")
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppColor.secondaryText)
                        .textCase(nil)
                } footer: {
                    IndonesianSpeech.text("Masukkan enam karakter kode undangan dari guru.")
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppColor.secondaryText)
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
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    JoinChannelSheet(isPresented: .constant(true), errorMessage: .constant(nil), isLoading: false) { _ in
        true
    }
}
