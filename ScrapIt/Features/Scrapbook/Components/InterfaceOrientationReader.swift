import SwiftUI
import UIKit

/// Reports the screen's orientation, also when the phone turns from one landscape side to the other, where the size
/// and the safe area stay the same (change 113).
struct InterfaceOrientationReader: UIViewRepresentable {
    let onChange: (UIInterfaceOrientation) -> Void

    func makeUIView(context: Context) -> ReaderView {
        ReaderView(onChange: onChange)
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.onChange = onChange
    }

    final class ReaderView: UIView {
        var onChange: (UIInterfaceOrientation) -> Void
        private var observation: NSKeyValueObservation?

        init(onChange: @escaping (UIInterfaceOrientation) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            observation = window?.windowScene?.observe(\.effectiveGeometry, options: [.initial, .new]) { [weak self] scene, _ in
                MainActor.assumeIsolated {
                    self?.onChange(scene.effectiveGeometry.interfaceOrientation)
                }
            }
        }
    }
}
