//
//  JoinChannelButton.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct JoinChannelButton: View {
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            IndonesianSpeech.text("Gabung Kelas")
        }
        .buttonStyle(MetraActionStyle(appearance: .secondary))
        .disabled(isDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IndonesianSpeech.text("Gabung kelas"))
        .accessibilityValue(IndonesianSpeech.text("Masukkan kode undangan dari guru"))
        .accessibilityHint(IndonesianSpeech.text("Buka formulir untuk memasukkan kode undangan kelas."))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: 16) {
        JoinChannelButton(action: {})
        JoinChannelButton(isDisabled: true, action: {})
    }
    .padding()
}
