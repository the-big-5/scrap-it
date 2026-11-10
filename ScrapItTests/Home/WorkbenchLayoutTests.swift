import CoreGraphics
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
