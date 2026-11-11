import CoreGraphics

/// Layout measurements from C6 - Metra, MIDFID - Student.
enum AppSize {
    enum Spacing {
        static let tight: CGFloat = 4
        static let small: CGFloat = 8
        static let actions: CGFloat = 10
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum Inset {
        static let page: CGFloat = 20
        static let sheet: CGFloat = 24
        static let readingCard: CGFloat = 14
        static let assistantCard: CGFloat = 20
    }

    enum Height {
        // Keep the existing minimum for tappable content without a larger Mid-Fi size.
        static let tapTarget: CGFloat = 44
        static let largeButton: CGFloat = 50
        static let searchField: CGFloat = 52
        static let documentRow: CGFloat = 65
        static let progressTrack: CGFloat = 5
    }

    enum Radius {
        static let callout: CGFloat = 12
        static let card: CGFloat = 14
        static let cameraPanel: CGFloat = 16
        static let assistantCard: CGFloat = 18
        static let largeButton: CGFloat = 25
    }

    static let largeIconContainer: CGFloat = 48
}
