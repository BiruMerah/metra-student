import SwiftUI

struct MetraActionStyle: ButtonStyle {
    var appearance: Appearance = .primary
    var fullWidth = true

    enum Appearance {
        case primary, secondary, destructive, neutral

        var fill: Color {
            switch self {
            case .primary: AppColor.brandFill
            case .secondary: AppColor.brandSubtle
            case .destructive: AppColor.danger.mix(with: .black, by: 0.30, in: .device)
            case .neutral: Color.primary.opacity(0.08)
            }
        }

        var foreground: Color {
            switch self {
            case .primary, .destructive: AppColor.onBrand
            case .secondary: AppColor.heading
            case .neutral: .primary
            }
        }
    }

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .metraActionLabel(appearance, fullWidth: fullWidth, isEnabled: isEnabled)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension View {
    func metraActionLabel(
        _ appearance: MetraActionStyle.Appearance,
        fullWidth: Bool = true,
        isEnabled: Bool = true
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppSize.Radius.largeButton, style: .circular)

        return font(AppTypography.body)
            .foregroundStyle(isEnabled ? appearance.foreground : Color.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSize.Inset.sheet)
            .padding(.vertical, AppSize.Spacing.small)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: AppSize.Height.largeButton)
            .background(isEnabled ? appearance.fill : Color.primary.opacity(0.06), in: shape)
            .contentShape(shape)
    }
}
