import PencilKit
import SwiftUI

/// PencilKit layer over a page (change 013). The drawing is kept in `ScrapbookPage.canvasSize` points and
/// zoomed to the page's size on screen, so it lines up on every device and on the covers.
/// While `isActive`, the system tool picker shows every tool available on iOS 18 except the reed pen
/// (iOS 26), and drawing with a finger is allowed (iPhones have no Apple Pencil). Inactive, it only shows
/// the drawing and lets touches through to the photos.
struct PencilCanvasView: UIViewRepresentable {
    let drawingData: Data?
    let isActive: Bool
    let onChange: (Data?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.isScrollEnabled = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentSize = ScrapbookPage.canvasSize
        canvas.contentInsetAdjustmentBehavior = .never
        if let drawingData, let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.fitToBounds()
        canvas.isUserInteractionEnabled = isActive
        context.coordinator.setToolPickerVisible(isActive)
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.setToolPickerVisible(false)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onChange: (Data?) -> Void
        weak var canvas: PKCanvasView?
        private var toolPicker: PKToolPicker?

        init(onChange: @escaping (Data?) -> Void) {
            self.onChange = onChange
        }

        /// Zooms the fixed drawing space to the page width.
        func fitToBounds() {
            guard let canvas, canvas.bounds.width > 0 else { return }
            let scale = canvas.bounds.width / ScrapbookPage.canvasSize.width
            guard abs(canvas.zoomScale - scale) > 0.0001 || canvas.minimumZoomScale != scale else { return }
            canvas.minimumZoomScale = scale
            canvas.maximumZoomScale = scale
            canvas.zoomScale = scale
            canvas.contentOffset = .zero
        }

        private var isPickerShown = false

        func setToolPickerVisible(_ visible: Bool) {
            guard let canvas, visible != isPickerShown else { return }
            isPickerShown = visible
            if visible {
                let picker = toolPicker ?? Self.makeToolPicker()
                toolPicker = picker
                picker.addObserver(canvas)
                picker.setVisible(true, forFirstResponder: canvas)
                DispatchQueue.main.async { canvas.becomeFirstResponder() }
            } else if let picker = toolPicker {
                picker.setVisible(false, forFirstResponder: canvas)
                picker.removeObserver(canvas)
                canvas.resignFirstResponder()
            }
        }

        /// Every iOS 18 tool, listed explicitly so the reed pen (iOS 26) never shows.
        private static func makeToolPicker() -> PKToolPicker {
            let inks: [PKInkingTool.InkType] = [.pen, .pencil, .marker, .monoline, .fountainPen, .watercolor, .crayon]
            var items: [PKToolPickerItem] = inks.map { PKToolPickerInkingItem(type: $0) }
            items.append(PKToolPickerEraserItem(type: .vector))
            items.append(PKToolPickerEraserItem(type: .bitmap))
            items.append(PKToolPickerLassoItem())
            items.append(PKToolPickerRulerItem())
            return PKToolPicker(toolItems: items)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            onChange(drawing.strokes.isEmpty ? nil : drawing.dataRepresentation())
        }
    }
}
