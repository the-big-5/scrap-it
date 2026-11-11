import AVFoundation
import Testing
import UIKit
@testable import ScrapIt

@Suite struct CameraOrientationTests {
    @Test func landscapeLeftResolvesToLeftSide() {
        let side = RollCameraOrientation.landscapeSide(for: .landscapeLeft)
        #expect(side == .left)
        #expect(side?.viewRotationDegrees == 90.0)
        #expect(side?.cameraAngleDelta == 0.0)
    }

    @Test func landscapeRightResolvesToRightSide() {
        let side = RollCameraOrientation.landscapeSide(for: .landscapeRight)
        #expect(side == .right)
        #expect(side?.viewRotationDegrees == -90.0)
        #expect(side?.cameraAngleDelta == 180.0)
    }

    @Test func cameraReturnAngleResolvesPortraitAndBothLandscapeSides() {
        #expect(RollCameraOrientation.cameraReturnAngle(deviceOrientation: .portrait) == 0.0)
        #expect(RollCameraOrientation.cameraReturnAngle(deviceOrientation: .landscapeLeft) == 90.0)
        #expect(RollCameraOrientation.cameraReturnAngle(deviceOrientation: .landscapeRight) == -90.0)
    }

    @Test func nonLandscapeOrientationsReturnNilToRetainPreviousState() {
        let nonLandscape: [UIDeviceOrientation] = [
            .portrait,
            .portraitUpsideDown,
            .faceUp,
            .faceDown,
            .unknown,
        ]

        for orientation in nonLandscape {
            #expect(RollCameraOrientation.landscapeSide(for: orientation) == nil)
        }
    }

    @Test func accelerometerResolvesLeftSideWhenXNegative() {
        let side = RollCameraOrientation.landscapeSide(accelerationX: -0.8, accelerationY: -0.1, accelerationZ: 0.2)
        #expect(side == .left)
    }

    @Test func accelerometerResolvesRightSideWhenXPositive() {
        let side = RollCameraOrientation.landscapeSide(accelerationX: 0.8, accelerationY: 0.1, accelerationZ: 0.2)
        #expect(side == .right)
    }

    @Test func accelerometerReturnsNilWhenDeviceIsFlat() {
        // High Z indicates lying flat on a table face up or face down
        let faceUp = RollCameraOrientation.landscapeSide(accelerationX: -0.7, accelerationY: 0.1, accelerationZ: 0.95)
        let faceDown = RollCameraOrientation.landscapeSide(accelerationX: 0.7, accelerationY: 0.1, accelerationZ: -0.92)
        #expect(faceUp == nil)
        #expect(faceDown == nil)
    }

    @Test func accelerometerReturnsNilWhenDeviceIsVertical() {
        // Y dominant over X indicates portrait upright or upside down
        let portraitUpright = RollCameraOrientation.landscapeSide(accelerationX: -0.2, accelerationY: -0.9, accelerationZ: 0.1)
        let portraitInverted = RollCameraOrientation.landscapeSide(accelerationX: 0.3, accelerationY: 0.85, accelerationZ: 0.1)
        #expect(portraitUpright == nil)
        #expect(portraitInverted == nil)
    }

    @Test func accelerometerReturnsNilWithinDeadband() {
        let neutral = RollCameraOrientation.landscapeSide(accelerationX: 0.15, accelerationY: 0.1, accelerationZ: 0.5)
        #expect(neutral == nil)
    }

    @Test func viewRotationInPortraitAnchorsToReferenceLandscape() {
        #expect(RollCameraOrientation.viewRotationDegrees(isPortraitWindow: true, physicalSide: .left) == 90.0)
        #expect(RollCameraOrientation.viewRotationDegrees(isPortraitWindow: true, physicalSide: .right) == 90.0)
    }

    @Test func viewRotationInLandscapeFollowsNativeWhenAligned() {
        #expect(RollCameraOrientation.viewRotationDegrees(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeRight,
            physicalSide: .left
        ) == 0.0)
        #expect(RollCameraOrientation.viewRotationDegrees(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeRight,
            physicalSide: .right
        ) == 0.0)
    }

    @Test func viewRotationInLandscapeFlips180WhenWindowIsLandscapeLeft() {
        #expect(RollCameraOrientation.viewRotationDegrees(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeLeft,
            physicalSide: .left
        ) == 180.0)
        #expect(RollCameraOrientation.viewRotationDegrees(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeLeft,
            physicalSide: .right
        ) == 180.0)
    }

    @Test func cameraRotationDeltaInPortraitAnchorsToReferenceLandscape() {
        #expect(RollCameraOrientation.cameraRotationDelta(isPortraitWindow: true, physicalSide: .left, cameraPosition: .back) == -90.0)
        #expect(RollCameraOrientation.cameraRotationDelta(isPortraitWindow: true, physicalSide: .right, cameraPosition: .back) == -90.0)
        #expect(RollCameraOrientation.cameraRotationDelta(isPortraitWindow: true, physicalSide: .left, cameraPosition: .front) == 90.0)
        #expect(RollCameraOrientation.cameraRotationDelta(isPortraitWindow: true, physicalSide: .right, cameraPosition: .front) == 90.0)
    }

    @Test func cameraRotationDeltaInLandscapeFollowsNativeWhenAligned() {
        #expect(RollCameraOrientation.cameraRotationDelta(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeRight,
            physicalSide: .left
        ) == 0.0)
        #expect(RollCameraOrientation.cameraRotationDelta(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeRight,
            physicalSide: .right
        ) == 0.0)
    }

    @Test func cameraRotationDeltaInLandscapeOffsets180WhenWindowIsLandscapeLeft() {
        #expect(RollCameraOrientation.cameraRotationDelta(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeLeft,
            physicalSide: .left
        ) == 180.0)
        #expect(RollCameraOrientation.cameraRotationDelta(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeLeft,
            physicalSide: .right
        ) == 180.0)
    }

    @Test func effectiveCameraAngleKeepsBaseForLeftSide() {
        #expect(RollCameraOrientation.effectiveCameraAngle(baseAngle: 90, side: .left) == 90)
        #expect(RollCameraOrientation.effectiveCameraAngle(baseAngle: 270, side: .left) == 270)
        #expect(RollCameraOrientation.effectiveCameraAngle(baseAngle: 0, side: .left) == 0)
        #expect(RollCameraOrientation.effectiveCameraAngle(baseAngle: 180, side: .left) == 180)
    }

    @Test func effectiveCameraAngleOffsetsBy180ForRightSide() {
        #expect(RollCameraOrientation.effectiveCameraAngle(baseAngle: 90, side: .right) == 270)
        #expect(RollCameraOrientation.effectiveCameraAngle(baseAngle: 270, side: .right) == 90)
        #expect(RollCameraOrientation.effectiveCameraAngle(baseAngle: 0, side: .right) == 180)
        #expect(RollCameraOrientation.effectiveCameraAngle(baseAngle: 180, side: .right) == 0)
    }

    // MARK: - Change 057 Portrait Orientation Tests

    @Test func deviceOrientationResolvesPortraitAndLandscapeSides() {
        #expect(RollCameraOrientation.deviceOrientation(for: .portrait) == .portrait)
        #expect(RollCameraOrientation.deviceOrientation(for: .landscapeLeft) == .landscapeLeft)
        #expect(RollCameraOrientation.deviceOrientation(for: .landscapeRight) == .landscapeRight)
        #expect(RollCameraOrientation.deviceOrientation(for: .portraitUpsideDown) == nil)
        #expect(RollCameraOrientation.deviceOrientation(for: .faceUp) == nil)
        #expect(RollCameraOrientation.deviceOrientation(for: .unknown) == nil)
    }

    @Test func accelerometerResolvesPortraitUprightWhenYNegativeDominant() {
        let portrait = RollCameraOrientation.deviceOrientation(
            accelerationX: -0.15,
            accelerationY: -0.92,
            accelerationZ: 0.1
        )
        #expect(portrait == .portrait)
        #expect(portrait?.isPortrait == true)
        #expect(portrait?.landscapeSide == nil)
    }

    @Test func accelerometerIgnoresInvertedPortrait() {
        let inverted = RollCameraOrientation.deviceOrientation(
            accelerationX: 0.1,
            accelerationY: 0.88,
            accelerationZ: 0.1
        )
        #expect(inverted == nil)
    }

    @Test func accelerometerResolvesLandscapeSidesForDeviceOrientation() {
        let left = RollCameraOrientation.deviceOrientation(
            accelerationX: -0.85,
            accelerationY: -0.1,
            accelerationZ: 0.15
        )
        let right = RollCameraOrientation.deviceOrientation(
            accelerationX: 0.82,
            accelerationY: 0.08,
            accelerationZ: 0.12
        )
        #expect(left == .landscapeLeft)
        #expect(left?.landscapeSide == .left)
        #expect(right == .landscapeRight)
        #expect(right?.landscapeSide == .right)
    }

    @Test func photoCaptureAngleUsesPortraitAngleWhenDeviceIsPortrait() {
        let portraitAngleFromLeft = RollCameraOrientation.photoCaptureAngle(
            deviceOrientation: .portrait,
            landscapeAngle: 0.0
        )
        let portraitAngleFromRight = RollCameraOrientation.photoCaptureAngle(
            deviceOrientation: .portrait,
            landscapeAngle: 180.0
        )
        #expect(portraitAngleFromLeft == 90.0)
        #expect(portraitAngleFromRight == 90.0)
    }

    @Test func photoCaptureAngleUsesLandscapeAngleWhenDeviceIsLandscape() {
        let leftAngle = RollCameraOrientation.photoCaptureAngle(
            deviceOrientation: .landscapeLeft,
            landscapeAngle: 0.0,
            cameraPosition: .back
        )
        let rightAngle = RollCameraOrientation.photoCaptureAngle(
            deviceOrientation: .landscapeRight,
            landscapeAngle: 180.0,
            cameraPosition: .back
        )
        #expect(leftAngle == 0.0)
        #expect(rightAngle == 180.0)

        let frontLeftAngle = RollCameraOrientation.photoCaptureAngle(
            deviceOrientation: .landscapeLeft,
            landscapeAngle: 0.0,
            cameraPosition: .front
        )
        let frontRightAngle = RollCameraOrientation.photoCaptureAngle(
            deviceOrientation: .landscapeRight,
            landscapeAngle: 180.0,
            cameraPosition: .front
        )
        #expect(frontLeftAngle == 180.0)
        #expect(frontRightAngle == 0.0)

        let frontPortraitAngle = RollCameraOrientation.photoCaptureAngle(
            deviceOrientation: .portrait,
            landscapeAngle: 0.0,
            cameraPosition: .front
        )
        #expect(frontPortraitAngle == 90.0)
    }

    @Test func symbolRotationResolvesAngles() {
        #expect(RollCameraOrientation.symbolRotationDegrees(for: .landscapeLeft) == 0.0)
        #expect(RollCameraOrientation.symbolRotationDegrees(for: .portrait) == -90.0)
        #expect(RollCameraOrientation.symbolRotationDegrees(for: .landscapeRight) == -180.0)
    }

    @Test func zoomTextRotationFollowsLandscapeSideAndRetainsInPortrait() {
        #expect(RollCameraOrientation.zoomTextRotationDegrees(for: .landscapeLeft, previousRotation: 0) == 0.0)
        #expect(RollCameraOrientation.zoomTextRotationDegrees(for: .landscapeRight, previousRotation: 0) == 180.0)
        #expect(RollCameraOrientation.zoomTextRotationDegrees(for: .portrait, previousRotation: 0.0) == 0.0)
        #expect(RollCameraOrientation.zoomTextRotationDegrees(for: .portrait, previousRotation: 180.0) == 180.0)
    }

    @Test func hudElementRotationCompensatesForDeviceOrientation() {
        #expect(RollCameraOrientation.hudElementRotationDegrees(
            deviceOrientation: .portrait,
            simulatedLandscapeSide: .left
        ) == -90.0)

        #expect(RollCameraOrientation.hudElementRotationDegrees(
            deviceOrientation: .portrait,
            simulatedLandscapeSide: .right
        ) == -90.0)

        #expect(RollCameraOrientation.hudElementRotationDegrees(
            deviceOrientation: .landscapeLeft,
            simulatedLandscapeSide: .left
        ) == 0.0)

        #expect(RollCameraOrientation.hudElementRotationDegrees(
            deviceOrientation: .landscapeRight,
            simulatedLandscapeSide: .right
        ) == -180.0)
    }

    // MARK: - Viewfinder dimensions (change 072)

    @Test func viewfinderDimensionsMatchFigmaNode145826041() {
        let dims = RollCameraOrientation.viewfinderDimensions
        #expect(dims.outerHeight == 337.0)
        #expect(dims.innerHeight == 318.0)
        #expect(dims.innerWidth == 424.0)
        #expect(abs((dims.innerWidth / dims.innerHeight) - (4.0 / 3.0)) < 0.0001)
        #expect(dims.outerWidth == 444.406)
    }
}
