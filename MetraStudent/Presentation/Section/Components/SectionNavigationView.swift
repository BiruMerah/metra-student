//
//  SectionNavigationView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct SectionNavigationView: View {
    let title: String
    var appearance: MetraActionStyle.Appearance = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IndonesianSpeech.text(title)
        }
        .buttonStyle(MetraActionStyle(appearance: appearance))
        .accessibilityLabel(IndonesianSpeech.text(title))
    }
}

#Preview {
    SectionNavigationView(title: "Segmen Selanjutnya", action: {})
        .padding()
}
