import SwiftUI

extension View {
    func metraCard(
        radius: CGFloat = AppSize.Radius.card,
        fill: Color = Color(.secondarySystemGroupedBackground),
        border: Color = Color(.separator).opacity(0.45)
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)

        return background(fill, in: shape)
            .overlay {
                shape.strokeBorder(border, lineWidth: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}
