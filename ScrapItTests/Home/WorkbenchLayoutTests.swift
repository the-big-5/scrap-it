import CoreGraphics
import SwiftData
import Testing
@testable import ScrapIt

@MainActor
struct WorkbenchLayoutTests {
    /// iPhone 17 / Air size (Figma frame), iPhone SE, iPhone 17 Pro Max.
    static let screens: [CGSize] = [
        CGSize(width: 402, height: 874),
        CGSize(width: 375, height: 667),
        CGSize(width: 440, height: 956),
    ]

    @Test func figmaFrameMapsOneToOne() {
        let layout = WorkbenchLayout(container: CGSize(width: 402, height: 874))

        #expect(layout.scale == 1)
        #expect(layout.origin == .zero)
        #expect(layout.rect(CGRect(x: 13, y: 0, width: 389, height: 423.607)) == CGRect(x: 13, y: 0, width: 389, height: 423.607))
    }

    @Test(arguments: screens)
    func scaleIsUniformByWidth(_ screen: CGSize) {
        let layout = WorkbenchLayout(container: screen)
        let rect = layout.rect(CGRect(x: 0, y: 0, width: 100, height: 50))

        #expect(abs(layout.scale - screen.width / 402) < 0.0001)
        #expect(abs(rect.width / rect.height - 2) < 0.0001, "No separate X/Y stretching")
    }

    @Test(arguments: screens)
    func deskIsCenteredVertically(_ screen: CGSize) {
        let layout = WorkbenchLayout(container: screen)
        let desk = layout.rect(CGRect(origin: .zero, size: WorkbenchLayout.designSize))

        #expect(abs(desk.minX) < 0.0001)
        #expect(abs(desk.maxX - screen.width) < 0.0001)
        #expect(abs(desk.midY - screen.height / 2) < 0.0001)
    }

    @Test(arguments: screens)
    func objectsKeepTheirRelativeSpot(_ screen: CGSize) {
        let layout = WorkbenchLayout(container: screen)
        let camera = layout.point(WorkbenchLayout.cameraIdleCenter)
        let desk = layout.rect(CGRect(origin: .zero, size: WorkbenchLayout.designSize))

        #expect(abs((camera.x - desk.minX) / desk.width - 111.707 / 402) < 0.0001)
        #expect(abs((camera.y - desk.minY) / desk.height - 375.738 / 874) < 0.0001)
    }

    @Test func deskCoversEveryIPhoneScreen() {
        // The desk is 402×874; on every iPhone shape it covers the full screen, so nothing outside
        // the Figma frame (where the exports are cut) is ever visible.
        for screen in Self.screens {
            let layout = WorkbenchLayout(container: screen)
            #expect(layout.origin.y <= 0.5, "\(screen)")
        }
    }

    @Test func everyDeskAssetIsUniqueAndInsideTheFrame() {
        let items = WorkbenchLayout.deskItems + [WorkbenchLayout.tutorialBook]
        #expect(Set(items.map(\.asset)).count == items.count)
        let bounds = CGRect(origin: .zero, size: WorkbenchLayout.designSize)
        for item in items {
            #expect(bounds.insetBy(dx: -0.5, dy: -0.5).contains(item.frame), "\(item.asset)")
        }
    }

    @Test(arguments: screens)
    func zoomedCameraScaleSizesProperlyForLandscapeAndPortraitAngles(_ screen: CGSize) {
        let layoutScale = screen.width / WorkbenchLayout.designSize.width

        // Landscape left / right angles (+90 / -90): fits vertically with clean margin from screen edges
        for angle in [90.0, -90.0] {
            let scale = WorkbenchLayout.zoomedCameraScale(container: screen, layoutScale: layoutScale, angle: angle)
            let visualCameraHeight = WorkbenchLayout.cameraBodyHeight * layoutScale * scale

            #expect(visualCameraHeight < screen.width, "Camera body has vertical margin from edge in landscape at angle \(angle)")
            #expect(visualCameraHeight >= screen.width * 0.7, "Camera body is prominently zoomed in landscape at angle \(angle)")
        }

        // Upright angle (0.0): covers viewport
        let portraitScale = WorkbenchLayout.zoomedCameraScale(container: screen, layoutScale: layoutScale, angle: 0.0)
        let visualWidthPortrait = WorkbenchLayout.cameraSize.width * layoutScale * portraitScale
        let visualHeightPortrait = WorkbenchLayout.cameraSize.height * layoutScale * portraitScale

        #expect(visualWidthPortrait >= screen.width, "Width covers screen at angle 0")
        #expect(visualHeightPortrait >= screen.height, "Height covers screen at angle 0")
    }

    @Test(arguments: screens)
    func zoomedCameraCenterAlignsPhysicalBodyToScreenCenter(_ screen: CGSize) {
        let layoutScale = screen.width / WorkbenchLayout.designSize.width

        for angle in [0.0, 90.0, -90.0] {
            let scale = WorkbenchLayout.zoomedCameraScale(container: screen, layoutScale: layoutScale, angle: angle)
            let pos = WorkbenchLayout.zoomedCameraCenter(container: screen, layoutScale: layoutScale, angle: angle, scale: scale)
            let rad = angle * .pi / 180.0
            let rx = (WorkbenchLayout.cameraBodyCenterOffset.x * cos(rad) - WorkbenchLayout.cameraBodyCenterOffset.y * sin(rad)) * scale * layoutScale
            let ry = (WorkbenchLayout.cameraBodyCenterOffset.x * sin(rad) + WorkbenchLayout.cameraBodyCenterOffset.y * cos(rad)) * scale * layoutScale
            let visualCameraCenter = CGPoint(x: pos.x + rx, y: pos.y + ry)

            #expect(abs(visualCameraCenter.x - screen.width / 2) < 0.001, "X centered for angle \(angle) on screen \(screen)")
            #expect(abs(visualCameraCenter.y - screen.height / 2) < 0.001, "Y centered for angle \(angle) on screen \(screen)")
        }
    }

    @Test func routerCameraReturnLifecycleControlsPhaseAndTabBarVisibility() {
        let router = AppRouter()
        #expect(router.cameraReturnPhase == .idle)
        #expect(router.shouldShowTabBar)

        router.beginCameraReturn(angle: 90.0)
        #expect(router.cameraReturnPhase == .zoomedIn)
        #expect(router.cameraReturnAngle == 90.0)
        #expect(router.isTabBarHidden)
        #expect(!router.shouldShowTabBar)

        router.animateCameraReturnToIdle()
        #expect(router.cameraReturnPhase == .animatingToIdle)
        #expect(!router.shouldShowTabBar)

        router.finishCameraReturn()
        #expect(router.cameraReturnPhase == .idle)
        #expect(!router.isTabBarHidden)
        #expect(router.shouldShowTabBar)
    }

    @Test func workbenchViewModelForwardsCameraReturnTransitions() throws {
        let schema = Schema([Scrapbook.self, ScrapPhoto.self, CaptureSession.self, ScrapbookPage.self, ScrapbookItem.self, StickerSheet.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let router = AppRouter()
        let store = SessionStore(modelContext: container.mainContext)
        let vm = WorkbenchViewModel(modelContext: container.mainContext, navigator: router, sessionStore: store)

        router.beginCameraReturn(angle: -90.0)
        #expect(vm.cameraReturnPhase == .zoomedIn)
        #expect(vm.cameraReturnAngle == -90.0)

        vm.animateCameraReturnToIdle()
        #expect(vm.cameraReturnPhase == .animatingToIdle)

        vm.finishCameraReturn()
        #expect(vm.cameraReturnPhase == .idle)
    }

    @Test func cameraFlipMathResolvesTwoSidedCardProgression() {
        // Start: camera back face visible at 0°
        #expect(!CameraFlipMath.isFrontFacing(angle: 0.0))
        #expect(CameraFlipMath.backAngle(for: 0.0) == 0.0)

        // Mid-flip prior to edge-on boundary
        #expect(!CameraFlipMath.isFrontFacing(angle: 45.0))
        #expect(CameraFlipMath.backAngle(for: 45.0) == 45.0)
        #expect(!CameraFlipMath.isFrontFacing(angle: 89.9))

        // Midpoint boundary: edge-on transition to camera front face
        #expect(CameraFlipMath.isFrontFacing(angle: 90.0))
        #expect(CameraFlipMath.frontAngle(for: 90.0) == -90.0)

        // Rotating into view
        #expect(CameraFlipMath.isFrontFacing(angle: 135.0))
        #expect(CameraFlipMath.frontAngle(for: 135.0) == -45.0)

        // End of flip: front face fully facing forward
        #expect(CameraFlipMath.isFrontFacing(angle: 180.0))
        #expect(CameraFlipMath.frontAngle(for: 180.0) == 0.0)
    }

    @Test func cameraReturnOrientationAnglesPreserveLocalYAxisAcrossOrientations() {
        let portraitAngle = RollCameraOrientation.cameraReturnAngle(deviceOrientation: .portrait)
        let landscapeLeftAngle = RollCameraOrientation.cameraReturnAngle(deviceOrientation: .landscapeLeft)
        let landscapeRightAngle = RollCameraOrientation.cameraReturnAngle(deviceOrientation: .landscapeRight)

        #expect(portraitAngle == 0.0)
        #expect(landscapeLeftAngle == 90.0)
        #expect(landscapeRightAngle == -90.0)
    }

    @Test func cameraReturnScaleStagesProgressFromFullBleedToFloatingToIdle() {
        let container = CGSize(width: 393, height: 852)
        let layoutScale: CGFloat = 1.0

        let portraitFullBleed = WorkbenchLayout.fullBleedCameraScale(container: container, layoutScale: layoutScale, angle: 0.0)
        let portraitFloating = WorkbenchLayout.floatingCameraScale(container: container, layoutScale: layoutScale, angle: 0.0)

        #expect(portraitFullBleed > portraitFloating)
        #expect(portraitFloating > 1.0)

        let landscapeFullBleed = WorkbenchLayout.fullBleedCameraScale(container: container, layoutScale: layoutScale, angle: 90.0)
        let landscapeFloating = WorkbenchLayout.floatingCameraScale(container: container, layoutScale: layoutScale, angle: 90.0)

        #expect(landscapeFullBleed > landscapeFloating)
        #expect(landscapeFloating > 1.0)
    }
}

struct TabBarDragMathTests {
    let math = TabBarDragMath(barWidth: 186, horizontalPadding: 6, tabCount: 2)

    @Test func tabUnderTheFinger() {
        #expect(math.tabIndex(atX: 20) == 0)
        #expect(math.tabIndex(atX: 160) == 1)
    }

    @Test func fingerPastTheEndsClamps() {
        #expect(math.tabIndex(atX: -50) == 0)
        #expect(math.tabIndex(atX: 500) == 1)
        #expect(math.pillCenter(forFingerX: -50) == math.center(ofTab: 0))
        #expect(math.pillCenter(forFingerX: 500) == math.center(ofTab: 1))
    }

    @Test func pillFollowsTheFingerBetweenTabs() {
        #expect(math.pillCenter(forFingerX: 93) == 93)
    }

    @Test func tabCentersAreSymmetric() {
        #expect(abs(math.center(ofTab: 0) - 49.5) < 0.0001)
        #expect(abs(math.center(ofTab: 1) - 136.5) < 0.0001)
        #expect(abs((math.center(ofTab: 0) + math.center(ofTab: 1)) / 2 - 93) < 0.0001)
    }
}
