import CoreGraphics
import Testing
@testable import ScrapIt

/// Two-finger zoom on the pages (change 114).
struct PageZoomTests {
    private func makeZoom() -> PageZoom {
        let zoom = PageZoom()
        zoom.viewport = CGRect(x: 0, y: 100, width: 400, height: 300)
        return zoom
    }

    @Test func zoomStaysBetweenOneAndTheMaximum() {
        let zoom = makeZoom()
        let center = CGPoint(x: 200, y: 250)
        zoom.pinchBegan(centroid: center)
        zoom.pinchChanged(magnification: 10, centroid: center)
        #expect(zoom.scale == PageZoom.maxScale)
        zoom.pinchBegan(centroid: center)
        zoom.pinchChanged(magnification: 0.01, centroid: center)
        #expect(zoom.scale == 1)
        #expect(zoom.offset == .zero)
        #expect(!zoom.isZoomed)
    }

    @Test func thePointBetweenTheFingersStaysUnderThem() {
        let zoom = makeZoom()
        // Fingers 100 pt right of the center: that page point stays there at 2×.
        let fingers = CGPoint(x: 300, y: 250)
        zoom.pinchBegan(centroid: fingers)
        zoom.pinchChanged(magnification: 2, centroid: fingers)
        #expect(zoom.scale == 2)
        let shownX: CGFloat = 100 * zoom.scale + zoom.offset.width
        #expect(abs(shownX - 100) < 0.001)
    }

    @Test func panningKeepsThePagesCoveringTheViewport() {
        let zoom = makeZoom()
        let center = CGPoint(x: 200, y: 250)
        zoom.pinchBegan(centroid: center)
        zoom.pinchChanged(magnification: 2, centroid: CGPoint(x: 2_000, y: 2_000))
        // At 2× the pages can move at most half the viewport's extra size.
        #expect(zoom.offset.width == 200)
        #expect(zoom.offset.height == 150)

        zoom.reset()
        #expect(zoom.scale == 1)
        #expect(zoom.offset == .zero)
    }
}
