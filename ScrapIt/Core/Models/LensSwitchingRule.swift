import Foundation

/// How the back camera may change lenses (change 018). On Pro iPhones the virtual multi-lens camera otherwise
/// jumps to the ultra-wide when the subject is close (automatic macro), which looks like a sudden zoom.
/// Between zooms the lens is locked; while the user zooms it may switch, then it is locked again.
nonisolated enum LensSwitchingRule: Equatable {
    /// Locked (`.locked`) while not zooming; `.restricted(.videoZoomChanged)` during a zoom change.
    case lockedBetweenZooms
    /// Leave the device as it is (front camera, single lens, or switching not supported).
    case unchanged

    /// Time after the last zoom change before the lens is locked again, so the zoom's own lens switch can finish.
    static let lockDelay: TimeInterval = 0.6

    static func resolve(isBackCamera: Bool, isVirtualDevice: Bool, supportsSwitchingBehavior: Bool) -> LensSwitchingRule {
        isBackCamera && isVirtualDevice && supportsSwitchingBehavior ? .lockedBetweenZooms : .unchanged
    }
}
