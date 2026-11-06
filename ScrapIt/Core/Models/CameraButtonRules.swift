import Foundation

/// What the "primary" physical event does. iOS sends the Camera Control click and volume down
/// as the same event (checked on device in the POC).
enum PrimaryButtonAction: Equatable {
    case capture
    case flipCamera

    /// With Camera Control both take a photo, like the system camera; without it volume down flips.
    static func resolve(hasCameraControl: Bool) -> PrimaryButtonAction {
        hasCameraControl ? .capture : .flipCamera
    }
}

/// "Turn On Camera Adjustments" pop-up rules (from the POC). iOS does not tell apps whether the setting
/// is on, so the pop-up shows (at most once per app launch) until the control has been seen opening
/// from a light press, or the user answers "Already On" / "Don't Remind Me".
struct CameraAdjustmentsPrompt {
    private enum Keys {
        static let confirmed = "cameraControlConfirmed.v2"
        static let dismissed = "cameraControlPromptDismissed.v2"
    }

    private let defaults: UserDefaults
    /// Shown already in this app launch.
    private(set) var shownThisLaunch = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isConfirmed: Bool { defaults.bool(forKey: Keys.confirmed) }
    var isDismissedForever: Bool { defaults.bool(forKey: Keys.dismissed) }

    /// Call when the camera is running. Returns `true` when the pop-up should be scheduled now.
    mutating func shouldShow(hasCameraControl: Bool) -> Bool {
        guard hasCameraControl, !isConfirmed, !isDismissedForever, !shownThisLaunch else { return false }
        shownThisLaunch = true
        return true
    }

    /// "Already On", or the control was seen opening (`sessionControlsWillEnterFullscreenAppearance`).
    func confirm() {
        defaults.set(true, forKey: Keys.confirmed)
    }

    /// "Don't Remind Me".
    func dismissForever() {
        defaults.set(true, forKey: Keys.dismissed)
    }
}
