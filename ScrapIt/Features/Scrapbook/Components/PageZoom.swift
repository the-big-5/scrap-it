import Observation
import SwiftUI
import UIKit

/// Two-finger zoom on the pages (change 114): the pages scale around the viewport's center and move by `offset`.
/// One pinch zooms and pans together: the page point between the fingers stays between them. 1×–3×, the pages
/// always cover the viewport.
@Observable
final class PageZoom {
    static let maxScale: CGFloat = 5

    private(set) var scale: CGFloat = 1
    private(set) var offset: CGSize = .zero
    /// The zoomed area on screen (window coordinates).
    @ObservationIgnored var viewport: CGRect = .zero

    @ObservationIgnored private var startScale: CGFloat = 1
    @ObservationIgnored private var startOffset: CGSize = .zero
    @ObservationIgnored private var startCentroid: CGPoint = .zero
    /// Fingers on the screen during the pinch.
    @ObservationIgnored var touchCount = 0

    var isZoomed: Bool { scale > 1.001 }

    /// `centroid`: the point between the fingers, in window coordinates.
    func pinchBegan(centroid: CGPoint) {
        startScale = scale
        startOffset = offset
        startCentroid = point(centroid)
    }

    /// `magnification`: since the pinch began.
    func pinchChanged(magnification: CGFloat, centroid: CGPoint) {
        let newScale = min(max(startScale * magnification, 1), Self.maxScale)
        let start = startCentroid
        let now = point(centroid)
        // The page point under the fingers at the start (relative to the center) stays under them.
        let x = now.x - newScale * (start.x - startOffset.width) / startScale
        let y = now.y - newScale * (start.y - startOffset.height) / startScale
        scale = newScale
        offset = clamped(CGSize(width: x, height: y), scale: newScale)
    }

    func reset() {
        scale = 1
        offset = .zero
    }

    /// Window point relative to the viewport's center.
    private func point(_ window: CGPoint) -> CGPoint {
        CGPoint(x: window.x - viewport.midX, y: window.y - viewport.midY)
    }

    private func clamped(_ offset: CGSize, scale: CGFloat) -> CGSize {
        let maxX = (scale - 1) * viewport.width / 2
        let maxY = (scale - 1) * viewport.height / 2
        return CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, -maxY), maxY))
    }
}

/// The pinch that drives `PageZoom` (two fingers: zoom and pan together).
struct PageZoomPinch: UIGestureRecognizerRepresentable {
    let zoom: PageZoom

    func makeUIGestureRecognizer(context: Context) -> TwoFingerPinchGestureRecognizer {
        TwoFingerPinchGestureRecognizer()
    }

    func handleUIGestureRecognizerAction(_ recognizer: TwoFingerPinchGestureRecognizer, context: Context) {
        PageZoomPinch.handle(recognizer, zoom: zoom)
    }

    static func handle(_ recognizer: UIPinchGestureRecognizer, zoom: PageZoom) {
        let centroid = recognizer.location(in: nil)
        switch recognizer.state {
        case .began:
            zoom.touchCount = recognizer.numberOfTouches
            zoom.pinchBegan(centroid: centroid)
        case .changed:
            // A finger lifted or added moves the point between the fingers: start again from here.
            if recognizer.numberOfTouches != zoom.touchCount {
                zoom.touchCount = recognizer.numberOfTouches
                recognizer.scale = 1
                zoom.pinchBegan(centroid: centroid)
            } else {
                zoom.pinchChanged(magnification: recognizer.scale, centroid: centroid)
            }
        default:
            break
        }
    }
}

/// A pinch that gives up as soon as one finger moves alone, so a stroke or a drag that waits for it isn't held back
/// (PencilKit doesn't start drawing until other pinches on the canvas have failed).
final class TwoFingerPinchGestureRecognizer: UIPinchGestureRecognizer {
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible, numberOfTouches < 2 {
            state = .failed
            return
        }
        super.touchesMoved(touches, with: event)
    }
}
