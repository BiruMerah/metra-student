import CloudKit
import UIKit

@MainActor
final class StudentCloudShareAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = StudentCloudShareSceneDelegate.self
        return configuration
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        ClassroomInvitationInbox.shared.receive(metadata)
    }
}

@MainActor
final class StudentCloudShareSceneDelegate: NSObject, UIWindowSceneDelegate {
    // Cold launch: metadata is delivered with the new scene's connection options.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let metadata = options.cloudKitShareMetadata { ClassroomInvitationInbox.shared.receive(metadata) }
    }

    // Running or suspended app: CloudKit delivers metadata to this callback.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        ClassroomInvitationInbox.shared.receive(metadata)
    }
}

extension ClassroomInvitationInbox {
    func receive(_ metadata: CKShare.Metadata) {
        guard metadata.containerIdentifier == CloudKitManager.shared.container.containerIdentifier else {
            errorMessage = ClassroomInvitationError.wrongContainer.errorDescription
            return
        }
        guard let url = metadata.share.url, (try? ClassroomInvitationLink(url: url)) != nil else {
            errorMessage = ClassroomInvitationError.invalidLink.errorDescription
            return
        }
        receive(url)
    }
}
