import SwiftUI

struct HomeListCardBackground: View {
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        let top = isFirst ? AppSize.Radius.assistantCard : 0
        let bottom = isLast ? AppSize.Radius.assistantCard : 0
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: top,
            bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom,
            topTrailingRadius: top
        )

        shape.fill(Color(.secondarySystemGroupedBackground))
            .overlay {
                shape.strokeBorder(AppColor.brand.opacity(0.18), lineWidth: 1)
                    .padding(.top, isFirst ? 0 : -1)
                    .padding(.bottom, isLast ? 0 : -1)
                    .clipped()
            }
    }
}
