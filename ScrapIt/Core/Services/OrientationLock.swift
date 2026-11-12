import UIKit

/// Orientation is set per screen: the Capture session stays portrait-locked with sensor-rotated controls
/// (changes 057, 072); outside capture, iPhone stays portrait while iPad supports all orientations.
enum OrientationLock {
    private(set) static var mask: UIInterfaceOrientationMask = defaultMask()

    static func defaultMask(
        for idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom
    ) -> UIInterfaceOrientationMask {
        idiom == .pad ? .all : .portrait
    }

    static func mask(
        isCaptureSessionVisible: Bool,
        idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom
    ) -> UIInterfaceOrientationMask {
        isCaptureSessionVisible ? .portrait : defaultMask(for: idiom)
    }

    /// Restores the device's default orientations outside the capture session (`.all` on iPad, `.portrait` on iPhone).
    static func resetToDefault() {
        set(defaultMask())
    }

    /// Preserved for existing callers outside this change; resets to the device default orientation mask.
    static func resetToPortrait() {
        resetToDefault()
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
