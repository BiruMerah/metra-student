import Foundation
import Observation

/// Retains links arriving before SwiftUI, onboarding, or the navigation stack.
@Observable @MainActor
final class ClassroomInvitationInbox {
    static let shared = ClassroomInvitationInbox()
    private(set) var links: [ClassroomInvitationLink]
    var errorMessage: String?
    private let defaults: UserDefaults
    private let storageKey = "metra.pendingClassroomInvitations.v1"
    var current: ClassroomInvitationLink? { links.first }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var seen: Set<String> = []
        links = (defaults.stringArray(forKey: storageKey) ?? []).compactMap { value in
            guard let url = URL(string: value), let link = try? ClassroomInvitationLink(url: url),
                  seen.insert(link.id).inserted else { return nil }
            return link
        }
    }

    func receive(_ url: URL) {
        guard let link = try? ClassroomInvitationLink(url: url), !links.contains(link) else { return }
        links.append(link)
        persist()
    }

    func finish(_ link: ClassroomInvitationLink) {
        links.removeAll { $0 == link }
        persist()
    }

    private func persist() {
        defaults.set(links.map { $0.url.absoluteString }, forKey: storageKey)
    }
}
