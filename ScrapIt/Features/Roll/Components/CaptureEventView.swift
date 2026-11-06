import AVKit
import SwiftUI
import UIKit

/// Captures physical camera events via `AVCaptureEventInteraction` (iOS 17.2+):
/// primary = Camera Control click / volume down (shutter capture)
/// secondary = volume up (flash mode toggle)
struct CaptureEventView: UIViewRepresentable {
    let isEnabled: Bool
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        if #available(iOS 17.2, *) {
            let coordinator = context.coordinator
            let interaction = AVCaptureEventInteraction { event in
                if event.phase == .ended {
                    coordinator.onPrimary?()
                }
            } secondary: { event in
                if event.phase == .ended {
                    coordinator.onSecondary?()
                }
            }
            view.addInteraction(interaction)
            coordinator.interaction = interaction
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPrimary = onPrimary
        context.coordinator.onSecondary = onSecondary
        if #available(iOS 17.2, *), let interaction = context.coordinator.interaction as? AVCaptureEventInteraction {
            interaction.isEnabled = isEnabled
        }
    }

    final class Coordinator {
        var onPrimary: (() -> Void)?
        var onSecondary: (() -> Void)?
        var interaction: AnyObject?
    }
}
