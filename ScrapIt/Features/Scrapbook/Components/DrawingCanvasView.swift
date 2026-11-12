import PencilKit
import SwiftUI

/// PencilKit canvas for the drawing layer being drawn (change 022, camera POC). The drawing space stays
/// `ScrapbookPage.canvasSize` and is zoomed to the page's size, so drawings fit every iPhone and the covers.
/// The pencil tray replaces the system tool picker. Finger and Apple Pencil both draw.
struct DrawingCanvasView: UIViewRepresentable {
    /// The pages this canvas draws on, left to right, and their layers' drawings (change 025: one canvas per page;
    /// change 104: one canvas over both pages of the spread, so a stroke can cross the gutter).
    let pageIDs: [UUID]
    let drawingData: [Data?]
    /// The size of one page.
    let pageSize: CGSize
    let controller: PencilController
    var remoteRevision: Int = 0
    /// Two fingers zoom and pan the pages while drawing, like Notes (change 114). `nil` = no zoom.
    var zoom: PageZoom?

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, lastRemoteRevision: remoteRevision, zoom: zoom)
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
        if zoom != nil {
            let pinch = TwoFingerPinchGestureRecognizer(target: context.coordinator,
                                                        action: #selector(Coordinator.pinch(_:)))
            canvas.addGestureRecognizer(pinch)
        }
        controller.attach(canvas, pageIDs: pageIDs, drawings: drawings,
                          pageWidth: ScrapbookPage.canvasSize(for: pageSize).width)
        applyScale(canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        applyScale(canvas)
        if context.coordinator.lastRemoteRevision != remoteRevision {
            context.coordinator.lastRemoteRevision = remoteRevision
            controller.replaceDrawings(drawings, canvas: canvas)
        }
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.controller.detach(canvas: canvas)
    }

    private var drawings: [PKDrawing] {
        drawingData.map { data in data.flatMap { try? PKDrawing(data: $0) } ?? PKDrawing() }
    }

    private func applyScale(_ canvas: PKCanvasView) {
        guard pageSize.height > 0 else { return }
        let scale = pageSize.height / ScrapbookPage.canvasSize.height
        let page = ScrapbookPage.canvasSize(for: pageSize)
        canvas.contentSize = CGSize(width: page.width * CGFloat(pageIDs.count), height: page.height)
        canvas.minimumZoomScale = scale
        canvas.maximumZoomScale = scale
        if abs(canvas.zoomScale - scale) > 0.0001 {
            canvas.zoomScale = scale
        }
        canvas.contentOffset = .zero
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let controller: PencilController
        var lastRemoteRevision: Int
        let zoom: PageZoom?

        init(controller: PencilController, lastRemoteRevision: Int, zoom: PageZoom?) {
            self.controller = controller
            self.lastRemoteRevision = lastRemoteRevision
            self.zoom = zoom
        }

        /// A second finger turns the touch into a zoom: the stroke the first finger started is dropped.
        @objc func pinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let zoom else { return }
            if recognizer.state == .began, let canvas = recognizer.view as? PKCanvasView {
                canvas.drawingGestureRecognizer.isEnabled = false
                canvas.drawingGestureRecognizer.isEnabled = true
            }
            PageZoomPinch.handle(recognizer, zoom: zoom)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            controller.drawingDidChange(canvasView.drawing, canvas: canvasView)
        }
    }
}
