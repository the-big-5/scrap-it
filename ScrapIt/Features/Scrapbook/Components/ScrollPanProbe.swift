import SwiftUI
import UIKit

/// A vertical pan inside a tray that scrolls sideways (change 022, camera POC).
///
/// A SwiftUI `DragGesture` inside a `ScrollView` (`simultaneousGesture` included) stops the tray from scrolling
/// on iOS 18 and later (brief K1). So the vertical gesture is added straight to the tray's `UIScrollView`
/// through this small view: it only begins when the finger moves vertically in the given direction, and
/// sideways scrolling stays fully with the scroll view.
struct ScrollPanProbe: UIViewRepresentable {
    enum Direction { case up, down }

    let direction: Direction
    /// Start point (window coordinates = `.global`). `false` = don't begin.
    var canBegin: (CGPoint) -> Bool = { _ in true }
    var onChanged: (CGPoint, CGSize) -> Void = { _, _ in }
    /// End point, translation, and `true` when the system cancelled it.
    var onEnded: (CGPoint, CGSize, Bool) -> Void = { _, _, _ in }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.coordinator = context.coordinator
        context.coordinator.probe = self
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        context.coordinator.probe = self
    }

    final class ProbeView: UIView {
        weak var coordinator: Coordinator?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var view = superview
            while let current = view, !(current is UIScrollView) { view = current.superview }
            if let scrollView = view as? UIScrollView { coordinator?.install(on: scrollView) }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var probe: ScrollPanProbe?
        private weak var pan: UIPanGestureRecognizer?

        func install(on scrollView: UIScrollView) {
            guard pan?.view !== scrollView else { return }
            if let pan { pan.view?.removeGestureRecognizer(pan) }
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
            recognizer.delegate = self
            scrollView.addGestureRecognizer(recognizer)
            // The scroll view waits until the direction is clear (this fails at once when moving sideways).
            scrollView.panGestureRecognizer.require(toFail: recognizer)
            pan = recognizer
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer, let probe else { return false }
            let velocity = pan.velocity(in: pan.view)
            guard abs(velocity.y) > abs(velocity.x) * 1.2 else { return false }
            guard probe.direction == .up ? velocity.y < 0 : velocity.y > 0 else { return false }
            let start = pan.location(in: nil)
            let translation = pan.translation(in: nil)
            return probe.canBegin(CGPoint(x: start.x - translation.x, y: start.y - translation.y))
        }

        @objc private func handle(_ pan: UIPanGestureRecognizer) {
            guard let probe else { return }
            let location = pan.location(in: nil)
            let t = pan.translation(in: nil)
            let translation = CGSize(width: t.x, height: t.y)
            switch pan.state {
            case .began, .changed: probe.onChanged(location, translation)
            case .ended: probe.onEnded(location, translation, false)
            case .cancelled, .failed: probe.onEnded(location, translation, true)
            default: break
            }
        }
    }
}
