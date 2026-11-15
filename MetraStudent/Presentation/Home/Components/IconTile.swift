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

    init(_ systemName: String, tint: Color = AppColor.brand, size: CGFloat = 40) {
        self.systemName = systemName
        self.tint = tint
        _size = ScaledMetric(wrappedValue: size, relativeTo: .headline)
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                tint == AppColor.brand ? AppColor.brandSubtle : tint.opacity(0.15),
                in: RoundedRectangle(cornerRadius: AppSize.Radius.callout)
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        IconTile("doc.text.fill")
        IconTile("sparkles")
        IconTile("checkmark.circle.fill", tint: AppColor.success)
    }
}
