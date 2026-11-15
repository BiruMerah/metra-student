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
            VStack(alignment: .leading, spacing: AppSize.Spacing.tight) {
                TextField("Contoh: Budi", text: $userName)
                    .font(AppTypography.body.weight(.medium))
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
                    } else if !isSignedInToiCloud {
                        Image(systemName: "exclamationmark.icloud")
                            .foregroundStyle(AppColor.danger)
                            .accessibilityHidden(true)
                    }
                    IndonesianSpeech.text(accountStatusMessage)
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppColor.secondaryText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(IndonesianSpeech.text("Status iCloud: \(accountStatusMessage)"))
            }
            .padding(.vertical, AppSize.Spacing.tight)
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
