import CloudKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Silent CloudKit pushes for room changes (change 011); no permission prompt needed.
        application.registerForRemoteNotifications()
        return true
    }

    /// Orientation is set per screen: the Capture session is landscape (left and right, like holding a camera),
    /// every other screen is portrait (from the POC).
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }

    /// Routes the scene to a delegate that receives iCloud share links (roll invites).
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = ShareAcceptingSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else { return .noData }
        NotificationCenter.default.post(name: .rollRoomDidChange, object: nil)
        return .newData
    }
}

enum OrientationLock {
    private(set) static var mask: UIInterfaceOrientationMask = .portrait

    static func mask(isCaptureSessionVisible: Bool) -> UIInterfaceOrientationMask {
        isCaptureSessionVisible ? .landscape : .portrait
    }

    /// Changes the allowed orientations and rotates the screen right away if needed.
    static func set(_ newMask: UIInterfaceOrientationMask) {
        guard newMask != mask else { return }
        mask = newMask
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: newMask)) { _ in }
        }
    }
}
