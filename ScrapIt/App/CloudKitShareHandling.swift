import CloudKit
import Observation
import UIKit

/// Holds an iCloud share (roll invite) the user just opened, until the signed-in app shell picks it up.
@Observable
final class IncomingShareInbox {
    static let shared = IncomingShareInbox()

    private(set) var pending: CKShare.Metadata?

    func receive(_ metadata: CKShare.Metadata) {
        pending = metadata
    }

    func take() -> CKShare.Metadata? {
        defer { pending = nil }
        return pending
    }
}

/// Receives iCloud share links (tap or AirDrop) for the SwiftUI scene. Needs `CKSharingSupported` (change 011).
final class ShareAcceptingSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            IncomingShareInbox.shared.receive(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        IncomingShareInbox.shared.receive(cloudKitShareMetadata)
    }
}
