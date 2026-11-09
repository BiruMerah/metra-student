//
//  JoinChannelSheet.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct JoinChannelSheet: View {
    @Binding var isPresented: Bool
    let isLoading: Bool
    let onJoin: (String) async -> Bool
    
    @State private var joinChannelCodeInput: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kode Channel (contoh: MTK10A)", text: $joinChannelCodeInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .font(.headline.monospaced())
                        .accessibilityLabel("Kolom Kode Channel")
                    
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
                            }
                            Text("Gabung")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(joinChannelCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                } header: {
                    Text("Kode Undangan Channel")
                } footer: {
                    Text("Masukkan 6 karakter kode channel yang diberikan oleh guru Anda.")
                }
            }
            .navigationTitle("Gabung Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    JoinChannelSheet(isPresented: .constant(true), isLoading: false) { _ in
        true
    }
}
