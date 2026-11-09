//
//  TintedRowBackground.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

/// Grouped-list cell background with a light tint on top. Use with `.listRowBackground(_:)`.
struct TintedRowBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            tint.opacity(0.1)
        }
    }
}
