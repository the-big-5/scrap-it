import SwiftUI
import WebKit

/// Hardware-accelerated WebKit view hosting the exact 3D camera intro animation (change 110).
/// References: CameraIntro.dc.html with 216 depth extrusion layers and dynamic film canister variant.
struct CameraIntroWebView: UIViewRepresentable {
    let filter: RollFilter
    var onZoomDeck: (() -> Void)?
    var onComplete: (() -> Void)?
    var onSkip: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "introBridge")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        let htmlString = CameraIntroHTMLTemplate.html(for: filter)
        webView.loadHTMLString(htmlString, baseURL: nil)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: CameraIntroWebView

        init(parent: CameraIntroWebView) {
            self.parent = parent
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let event = message.body as? String else { return }

            Task { @MainActor in
                switch event {
                case "haptic_open", "haptic_seated", "haptic_close":
                    HapticService.shared.playSnapFeedback()
                case "haptic_click":
                    HapticService.shared.playRatchetTick()
                case "phase_zoom_deck":
                    self.parent.onZoomDeck?()
                case "complete":
                    self.parent.onComplete?()
                case "skip":
                    self.parent.onSkip?()
                default:
                    break
                }
            }
        }
    }
}
