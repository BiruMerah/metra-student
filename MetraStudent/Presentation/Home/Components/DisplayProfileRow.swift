//
//  DisplayProfileRow.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct DisplayProfileRow: View {
    @Binding var userName: String
    let isInitialSyncing: Bool
    let isSignedInToiCloud: Bool
    let accountStatusMessage: String
    
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        Button {
            isNameFieldFocused = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title)
                    .foregroundStyle(AppColor.brand)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Contoh: Budi", text: $userName)
                        .font(AppTypography.headline)
                        .focused($isNameFieldFocused)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            isNameFieldFocused = false
                        }
                        .accessibilityLabel(IndonesianSpeech.text("Nama Tampilan Siswa"))
                    
                    HStack(spacing: 5) {
                        if isInitialSyncing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: isSignedInToiCloud ? "checkmark.icloud.fill" : "exclamationmark.icloud.fill")
                                .foregroundStyle(isSignedInToiCloud ? AppColor.success : AppColor.danger)
                        }
                        IndonesianSpeech.text(accountStatusMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(IndonesianSpeech.text("Status iCloud: \(accountStatusMessage)"))
                }
                
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    List {
        DisplayProfileRow(
            userName: .constant("Budi"),
            isInitialSyncing: false,
            isSignedInToiCloud: true,
            accountStatusMessage: "Terhubung ke iCloud"
        )
    }
}
