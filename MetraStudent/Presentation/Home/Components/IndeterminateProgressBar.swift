//
//  IndeterminateProgressBar.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

/// Indeterminate linear bar; shows a static segment when not animating (e.g. Reduce Motion).
struct IndeterminateProgressBar: View {
    var tint: Color = .accentColor
    var isAnimating: Bool = true
    private let cycle: TimeInterval = 1.4

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { context in
            let phase = isAnimating
                ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
                : 0.5
            GeometryReader { geometry in
                let width = geometry.size.width
                let segment = width * 0.35
                Capsule()
                    .fill(tint.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: segment)
                            .offset(x: -segment + (width + segment) * phase)
                    }
                    .clipShape(Capsule())
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

#Preview {
    IndeterminateProgressBar()
        .padding()
}
