import UIKit

/// Orientation is set per screen: the Capture session is landscape (left and right, like holding a camera),
/// every other screen is portrait (from the POC).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.mask
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
