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

    /// Physical device orientation recognized by the camera capture session.
    enum DeviceOrientation: Equatable, Sendable {
        case landscapeLeft   // Home button / USB-C on right (LandscapeSide.left)
        case landscapeRight  // Home button / USB-C on left (LandscapeSide.right)
        case portrait        // Device held upright in portrait

        var isPortrait: Bool {
            self == .portrait
        }

        var landscapeSide: LandscapeSide? {
            switch self {
            case .landscapeLeft: return .left
            case .landscapeRight: return .right
            case .portrait: return nil
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

    /// Resolves physical device orientation from `UIDeviceOrientation`.
    /// Returns `nil` for unsupported orientations (e.g. portraitUpsideDown, faceUp, unknown),
    /// indicating the existing orientation should be retained.
    static func deviceOrientation(for deviceOrientation: UIDeviceOrientation) -> DeviceOrientation? {
        switch deviceOrientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portrait:
            return .portrait
        default:
            return nil
        }
    }

    /// Resolves physical device orientation from raw accelerometer gravity values.
    /// Operates even when iOS system Portrait Orientation Lock is active.
    /// Returns `nil` for flat device, inverted portrait, or deadband.
    static func deviceOrientation(accelerationX: Double, accelerationY: Double, accelerationZ: Double) -> DeviceOrientation? {
        if abs(accelerationZ) > 0.85 {
            return nil
        }
        if abs(accelerationY) > abs(accelerationX) {
            if accelerationY < -0.25 {
                return .portrait
            }
            return nil
        }
        if accelerationX < -0.25 {
            return .landscapeLeft
        } else if accelerationX > 0.25 {
            return .landscapeRight
        }
        return nil
    }

    /// Standard upright portrait photo capture angle in AVFoundation on iOS (90°).
    static let portraitCaptureAngle: CGFloat = 90.0

    /// Determines the camera return angle (in degrees) relative to portrait workbench coordinates (change 086).
    /// Returns 0° when held upright in portrait, +90° for Landscape Left, and -90° for Landscape Right.
    static func cameraReturnAngle(
        deviceOrientation: DeviceOrientation,
        fallbackSide: LandscapeSide = .left
    ) -> Double {
        switch deviceOrientation {
        case .portrait:
            return 0.0
        case .landscapeLeft:
            return LandscapeSide.left.viewRotationDegrees
        case .landscapeRight:
            return LandscapeSide.right.viewRotationDegrees
        }
    }

    /// Resolves the photo capture rotation angle based on physical device orientation and landscape fallback.
    static func photoCaptureAngle(
        deviceOrientation: DeviceOrientation,
        landscapeAngle: CGFloat
    ) -> CGFloat {
        switch deviceOrientation {
        case .portrait:
            return portraitCaptureAngle
        case .landscapeLeft, .landscapeRight:
            return landscapeAngle
        }
    }

    /// Rotation angle (in degrees) to apply to viewfinder HUD elements (participant badge, buttons)
    /// to keep them upright relative to the user.
    static func hudElementRotationDegrees(
        deviceOrientation: DeviceOrientation,
        isPortraitWindow: Bool = false,
        windowInterfaceOrientation: UIInterfaceOrientation = .unknown,
        simulatedLandscapeSide: LandscapeSide = .left
    ) -> Double {
        guard deviceOrientation.isPortrait else { return 0.0 }
        switch simulatedLandscapeSide {
        case .left: return -90.0
        case .right: return 90.0
        }
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

    /// Fixed viewfinder bezel and inner preview dimensions in camera canvas points (change 071).
    /// Fixed 4:3 landscape in camera body coordinates (inner 313.33 x 235, outer 333.33 x 251),
    /// which naturally orients to 3:4 portrait relative to the user when held upright in portrait.
    static let viewfinderDimensions: (outerWidth: CGFloat, outerHeight: CGFloat, innerWidth: CGFloat, innerHeight: CGFloat) = {
        let innerHeight: CGFloat = 235.0
        let innerWidth: CGFloat = innerHeight * 4.0 / 3.0
        let outerWidth: CGFloat = innerWidth + 20.0
        let outerHeight: CGFloat = 251.0
        return (outerWidth, outerHeight, innerWidth, innerHeight)
    }()
}
