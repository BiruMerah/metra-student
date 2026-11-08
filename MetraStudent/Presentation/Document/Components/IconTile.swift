//
//  IconTile.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

/// Rounded, tinted square holding an SF Symbol. Scales with Dynamic Type.
struct IconTile: View {
    let systemName: String
    let tint: Color

    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 40

    init(_ systemName: String, tint: Color = .accentColor) {
        self.systemName = systemName
        self.tint = tint
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        IconTile("doc.text.fill")
        IconTile("sparkles", tint: .purple)
        IconTile("checkmark.circle.fill", tint: .green)
    }
}
