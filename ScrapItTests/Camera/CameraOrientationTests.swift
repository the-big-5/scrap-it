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

    @Test func viewRotationInPortraitRotatesForLeftAndRight() {
        #expect(RollCameraOrientation.viewRotationDegrees(isPortraitWindow: true, physicalSide: .left) == 90.0)
        #expect(RollCameraOrientation.viewRotationDegrees(isPortraitWindow: true, physicalSide: .right) == -90.0)
    }

    @Test func viewRotationInLandscapeFollowsNativeWhenAligned() {
        #expect(RollCameraOrientation.viewRotationDegrees(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeRight,
            physicalSide: .left
        ) == 0.0)
        #expect(RollCameraOrientation.viewRotationDegrees(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeLeft,
            physicalSide: .right
        ) == 0.0)
    }

    @Test func viewRotationInLandscapeFlips180WhenOrientationIsLockedOpposite() {
        #expect(RollCameraOrientation.viewRotationDegrees(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeRight,
            physicalSide: .right
        ) == 180.0)
        #expect(RollCameraOrientation.viewRotationDegrees(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeLeft,
            physicalSide: .left
        ) == 180.0)
    }

    @Test func cameraRotationDeltaInPortraitOffsetsRightBy180() {
        #expect(RollCameraOrientation.cameraRotationDelta(isPortraitWindow: true, physicalSide: .left) == 0.0)
        #expect(RollCameraOrientation.cameraRotationDelta(isPortraitWindow: true, physicalSide: .right) == 180.0)
    }

    @Test func cameraRotationDeltaInLandscapeFollowsNativeWhenAligned() {
        #expect(RollCameraOrientation.cameraRotationDelta(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeRight,
            physicalSide: .left
        ) == 0.0)
        #expect(RollCameraOrientation.cameraRotationDelta(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeLeft,
            physicalSide: .right
        ) == 0.0)
    }

    @Test func cameraRotationDeltaInLandscapeOffsets180WhenOrientationIsLockedOpposite() {
        #expect(RollCameraOrientation.cameraRotationDelta(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeRight,
            physicalSide: .right
        ) == 180.0)
        #expect(RollCameraOrientation.cameraRotationDelta(
            isPortraitWindow: false,
            windowInterfaceOrientation: .landscapeLeft,
            physicalSide: .left
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
}
