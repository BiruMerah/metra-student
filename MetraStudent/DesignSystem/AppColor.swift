import SwiftUI

enum AppColor {
    // Brand colors from C6 - Metra, HIFID - Student.
    static let brand = Color(.accent)
    // Keep the blue fill dark enough for its white label in both appearances.
    static let brandFill = Color(.metraBrandFill)
    static let onBrand = Color.white
    static let brandSubtle = Color(.metraBrandSubtle)
    static let heading = Color(.metraHeading)
    static let background = Color(.metraBackground)
    static let secondaryText = Color(.metraSecondaryText)

    static let warning = Color.orange
    static let danger = Color.red
    static let success = Color.green
}
