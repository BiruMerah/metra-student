import Accessibility
import SwiftUI

nonisolated enum IndonesianSpeech {
    static let languageTag = "id-ID"
    static let locale = Locale(identifier: languageTag)

    static func text(_ value: String, spokenAs: String? = nil) -> Text {
        Text(attributed(value, spokenAs: spokenAs))
    }

    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(attributed(message)).post()
    }

    static func attributed(_ value: String, spokenAs: String? = nil) -> AttributedString {
        var text = AttributedString(value)
        guard !value.isEmpty else { return text }
        var spoken = ""
        for scalar in (spokenAs ?? value).unicodeScalars {
            switch scalar {
            case "&": spoken += "&amp;"
            case "<": spoken += "&lt;"
            case ">": spoken += "&gt;"
            default:
                switch scalar.value {
                case 0x9, 0xA, 0xD, 0x20...0xFFFD, 0x10000...0x10FFFF:
                    spoken.unicodeScalars.append(scalar)
                default:
                    spoken += " "
                }
            }
        }
        text.accessibilitySpeechSSML = "<lang xml:lang=\"\(languageTag)\">\(spoken)</lang>"
        return text
    }
}

extension Label where Title == Text, Icon == Image {
    init(indonesian title: String, systemImage: String, spokenAs: String? = nil) {
        self.init {
            IndonesianSpeech.text(title, spokenAs: spokenAs)
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

extension Button where Label == Text {
    init(indonesian title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) { IndonesianSpeech.text(title) }
    }
}

extension Button where Label == SwiftUI.Label<Text, Image> {
    init(indonesian title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Label(indonesian: title, systemImage: systemImage) }
    }
}
