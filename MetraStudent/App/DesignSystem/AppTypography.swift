import SwiftUI

/// Metra's text styles use the system font and scale with Dynamic Type.
enum AppTypography {
    static let screenTitle = Font.largeTitle.bold()
    static let contentTitle = Font.title.bold()
    static let wordmark = Font.title3.weight(.semibold)
    static let headline = Font.headline

    static let body = Font.body
    static let readingBody = body.leading(.loose)
    static let callout = Font.callout
    static let supporting = Font.subheadline
    static let supportingEmphasis = supporting.weight(.semibold)
    static let caption = Font.caption

    static let accessCode = headline.monospaced()
}
