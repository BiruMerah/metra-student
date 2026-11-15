import SwiftUI

struct MetraWordmark: View {
    var body: some View {
        HStack(spacing: AppSize.Spacing.actions) {
            Image(.onboardingMetraMark)
                .resizable()
                .scaledToFit()
                .frame(width: 33, height: 31)
                .accessibilityHidden(true)
            IndonesianSpeech.text("Metra Student")
                .font(AppTypography.wordmark)
                .foregroundStyle(AppColor.heading)
        }
        .frame(minHeight: AppSize.Height.tapTarget)
    }
}
