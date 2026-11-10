import PencilKit
import SwiftUI

/// PencilKit canvas for the drawing layer being drawn (change 022, camera POC). The drawing space stays
/// `ScrapbookPage.canvasSize` and is zoomed to the page's size, so drawings fit every iPhone and the covers.
/// The pencil tray replaces the system tool picker. Finger and Apple Pencil both draw.
struct DrawingCanvasView: UIViewRepresentable {
    let drawingData: Data?
    let pageSize: CGSize
    let controller: PencilController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        // Without this PencilKit inverts ink in dark mode (black shows as white; brief K5).
        canvas.overrideUserInterfaceStyle = .light
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.isScrollEnabled = false
        canvas.bounces = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.delegate = context.coordinator
        let drawing = drawingData.flatMap { try? PKDrawing(data: $0) } ?? PKDrawing()
        controller.attach(canvas, drawing: drawing)
        applyScale(canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        applyScale(canvas)
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.controller.detach()
    }

    private func applyScale(_ canvas: PKCanvasView) {
        guard pageSize.width > 0 else { return }
        let scale = pageSize.width / ScrapbookPage.canvasSize.width
        canvas.contentSize = ScrapbookPage.canvasSize
        canvas.minimumZoomScale = scale
        canvas.maximumZoomScale = scale
        if abs(canvas.zoomScale - scale) > 0.0001 {
            canvas.zoomScale = scale
        }
        canvas.contentOffset = .zero
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let controller: PencilController

        init(controller: PencilController) {
            self.controller = controller
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            controller.drawingDidChange(canvasView.drawing)
        }
    }
}
