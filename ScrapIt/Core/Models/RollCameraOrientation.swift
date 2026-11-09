import Foundation
import UIKit

/// Calculates and manages camera orientation and rotation angles for the Capture session.
enum RollCameraOrientation {
    /// The landscape orientation used when orienting the camera UI.
    enum LandscapeSide: Equatable, Sendable {
        case left   // Home button / USB-C on right
        case right  // Home button / USB-C on left

        /// The default view rotation for simulated landscape in a portrait window.
        var viewRotationDegrees: Double {
            switch self {
            case .left: return 90.0
            case .right: return -90.0
            }
        }

        /// The default rotation delta to apply to `CameraEngine.rotationAngle`.
        var cameraAngleDelta: CGFloat {
            switch self {
            case .left: return 0.0
            case .right: return 180.0
            }
        }
    }

    /// Resolves the landscape side from physical device orientation (`UIDeviceOrientation`).
    /// Returns `nil` if the orientation is not landscape (e.g. portrait, faceUp, unknown),
    /// indicating that the existing landscape side should be retained.
    static func landscapeSide(for deviceOrientation: UIDeviceOrientation) -> LandscapeSide? {
        switch deviceOrientation {
        case .landscapeLeft:
            return .left
        case .landscapeRight:
            return .right
        default:
            return nil
        }
    }

    /// Resolves the landscape side from raw accelerometer gravity values.
    /// Operates even when iOS system Portrait Orientation Lock is active.
    /// Returns `nil` if the device is flat (high Z) or vertical (Y dominant over X),
    /// indicating the existing landscape side should be retained.
    static func landscapeSide(accelerationX: Double, accelerationY: Double, accelerationZ: Double) -> LandscapeSide? {
        if abs(accelerationZ) > 0.85 {
            return nil
        }
        if abs(accelerationY) > abs(accelerationX) {
            return nil
        }
        if accelerationX < -0.25 {
            return .left
        } else if accelerationX > 0.25 {
            return .right
        }
        return nil
    }

    /// Checks if a landscape window interface orientation aligns with the physical landscape side.
    /// In UIKit: `landscapeRight` has home button on right (matches `.left`),
    /// `landscapeLeft` has home button on left (matches `.right`).
    static func isWindowAligned(
        windowOrientation: UIInterfaceOrientation,
        physicalSide: LandscapeSide
    ) -> Bool {
        switch physicalSide {
        case .left:
            return windowOrientation == .landscapeRight
        case .right:
            return windowOrientation == .landscapeLeft
        }
    }

    /// Determines the view rotation angle (in degrees) to apply to `cameraBodyContent`
    /// given the current window geometry and physical device landscape side.
    static func viewRotationDegrees(
        isPortraitWindow: Bool,
        windowInterfaceOrientation: UIInterfaceOrientation = .unknown,
        physicalSide: LandscapeSide
    ) -> Double {
        if isPortraitWindow {
            switch physicalSide {
            case .left: return 90.0
            case .right: return -90.0
            }
        } else {
            let aligned = isWindowAligned(windowOrientation: windowInterfaceOrientation, physicalSide: physicalSide)
            return (aligned || windowInterfaceOrientation == .unknown) ? 0.0 : 180.0
        }
    }

    /// Determines the camera rotation delta (in degrees) to apply to `CameraEngine`
    /// given the current window geometry and physical device landscape side.
    static func cameraRotationDelta(
        isPortraitWindow: Bool,
        windowInterfaceOrientation: UIInterfaceOrientation = .unknown,
        physicalSide: LandscapeSide
    ) -> CGFloat {
        if isPortraitWindow {
            switch physicalSide {
            case .left: return 0.0
            case .right: return 180.0
            }
        } else {
            let aligned = isWindowAligned(windowOrientation: windowInterfaceOrientation, physicalSide: physicalSide)
            return (aligned || windowInterfaceOrientation == .unknown) ? 0.0 : 180.0
        }
    }

    /// Returns the effective camera rotation angle (in degrees, 0..<360) given a base coordinator angle and delta.
    static func effectiveCameraAngle(baseAngle: CGFloat, delta: CGFloat) -> CGFloat {
        let total = baseAngle + delta
        let normalized = total.truncatingRemainder(dividingBy: 360)
        return normalized < 0 ? normalized + 360 : normalized
    }

    /// Convenience wrapper using `LandscapeSide`.
    static func effectiveCameraAngle(baseAngle: CGFloat, side: LandscapeSide) -> CGFloat {
        effectiveCameraAngle(baseAngle: baseAngle, delta: side.cameraAngleDelta)
    }
}
