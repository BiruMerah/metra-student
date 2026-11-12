//
//  SectionNavigationView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct SectionNavigationView: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(indonesian: title, systemImage: symbol)
                .font(AppTypography.supportingEmphasis)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSize.Spacing.small)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .accessibilityLabel(IndonesianSpeech.text(title))
    }
}

#Preview {
    SectionNavigationView(title: "Segmen Selanjutnya", symbol: "forward.end.fill", action: {})
        .padding()
}
