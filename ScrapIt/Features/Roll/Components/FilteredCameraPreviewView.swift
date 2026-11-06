import SwiftUI
import UIKit

/// Live camera preview with the roll's filter applied (Metal layer fed by `CameraEngine`).
struct FilteredCameraPreviewView: UIViewRepresentable {
    let renderer: PreviewRenderer

    func makeUIView(context: Context) -> PreviewHostView {
        PreviewHostView(renderer: renderer)
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {}

    /// Hosts the renderer's `CAMetalLayer` and reports its pixel size on layout.
    /// The same layer tells `RotationCoordinator` which screen orientation the preview is on.
    final class PreviewHostView: UIView {
        private let renderer: PreviewRenderer

        init(renderer: PreviewRenderer) {
            self.renderer = renderer
            super.init(frame: .zero)
            backgroundColor = .black
            isUserInteractionEnabled = false
            layer.addSublayer(renderer.metalLayer)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            renderer.metalLayer.frame = bounds
            CATransaction.commit()

            let scale = window?.screen.scale ?? traitCollection.displayScale
            renderer.metalLayer.contentsScale = scale
            renderer.updateDrawableSize(CGSize(width: bounds.width * scale, height: bounds.height * scale))
        }
    }
}
