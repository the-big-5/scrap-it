import Observation
import PencilKit
import SwiftUI

/// Tools in the Pencil tray (change 022, Figma 1306:50774). No reed pen (iOS 26).
enum PencilToolKind: String, CaseIterable, Identifiable {
    case pen, brush, marker, crayon, fountain, eraser

    var id: String { rawValue }
    var assetName: String { "tray-pencil-\(rawValue)" }

    /// Full tool image height (pt), as the Figma instances (the long tool, not a cut-off part).
    var imageHeight: CGFloat {
        switch self {
        case .pen: 204
        case .brush: 200
        case .marker: 135
        case .crayon: 145
        case .fountain: 178
        case .eraser: 97
        }
    }

    /// Part of the tool showing above the tray's pocket (pt, from Figma).
    var visibleHeight: CGFloat {
        switch self {
        case .pen: 82
        case .brush: 86
        case .marker: 71
        case .crayon: 64
        case .fountain: 86
        case .eraser: 51
        }
    }

    var title: String {
        switch self {
        case .pen: "Pen"
        case .brush: "Brush"
        case .marker: "Marker"
        case .crayon: "Crayon"
        case .fountain: "Fountain Pen"
        case .eraser: "Eraser"
        }
    }

    /// Base width (the 3rd size of the size panel) in the `ScrapbookPage.canvasSize` space: the POC widths
    /// on 750 × 1000 scaled by 600 / 750.
    var baseWidth: CGFloat {
        switch self {
        case .pen: 4.8
        case .brush: 14.4
        case .marker: 12.8
        case .crayon: 11.2
        case .fountain: 5.6
        case .eraser: 22.4
        }
    }

    /// Horizontal shift so the tool's body is centered (the pen has a clip on one side).
    var centerOffset: CGFloat {
        self == .pen ? -4 : 0
    }
}

/// Pencil mode presentation state (change 022, camera POC): tool, color, size, and the undo history of the
/// layer being drawn. Saving is the editor ViewModel's job through `onDrawingChanged`.
@Observable
final class PencilController {
    /// The five sizes of the Figma size panel (strokes 0.68 / 1.275 / 1.955 / 2.805 / 3.995).
    static let widthMultipliers: [CGFloat] = [0.35, 0.65, 1, 1.43, 2.04]

    var tool: PencilToolKind = .pen { didSet { applyTool() } }
    var color: Color = Color(red: 0.11, green: 0.09, blue: 0.15) { didSet { applyTool() } }
    /// 0 (thinnest) to 4 (thickest).
    var widthLevel = 2 { didSet { applyTool() } }
    /// Ink opacity, 0.1–1 (slider in the size panel).
    var opacity: Double = 1 { didSet { applyTool() } }
    /// Size + opacity panel above the Pencil tray.
    var showsSizePanel = false
    private(set) var canUndo = false

    @ObservationIgnored weak var canvas: PKCanvasView?
    /// Called after each stroke and undo with the drawing data (`nil` = no strokes left).
    @ObservationIgnored var onDrawingChanged: ((Data?) -> Void)?
    @ObservationIgnored private var history: [PKDrawing] = []
    @ObservationIgnored private var current = PKDrawing()
    @ObservationIgnored private var isRestoring = false

    /// The eraser only erases where the finger passes (`.bitmap`), not whole strokes.
    var pkTool: PKTool {
        let width = tool.baseWidth * Self.widthMultipliers[widthLevel]
        let uiColor = UIColor(color).withAlphaComponent(opacity)
        switch tool {
        case .pen: return PKInkingTool(.pen, color: uiColor, width: width)
        case .brush: return PKInkingTool(.watercolor, color: uiColor, width: width)
        case .marker: return PKInkingTool(.marker, color: uiColor, width: width)
        case .crayon: return PKInkingTool(.crayon, color: uiColor, width: width)
        case .fountain: return PKInkingTool(.fountainPen, color: uiColor, width: width)
        case .eraser: return PKEraserTool(.bitmap, width: width)
        }
    }

    func attach(_ canvas: PKCanvasView, drawing: PKDrawing) {
        self.canvas = canvas
        current = drawing
        history = []
        canUndo = false
        isRestoring = true
        canvas.drawing = drawing
        isRestoring = false
        applyTool()
    }

    func replaceDrawingFromRemote(_ drawing: PKDrawing) {
        current = drawing
        isRestoring = true
        canvas?.drawing = drawing
        isRestoring = false
    }

    func detach() {
        canvas = nil
        history = []
        canUndo = false
    }

    func drawingDidChange(_ drawing: PKDrawing) {
        guard !isRestoring else { return }
        showsSizePanel = false
        history.append(current)
        if history.count > 50 { history.removeFirst() }
        current = drawing
        canUndo = true
        onDrawingChanged?(Self.data(of: drawing))
    }

    /// Undoes the last stroke of the active layer. No redo.
    func undo() {
        guard let previous = history.popLast() else { return }
        current = previous
        isRestoring = true
        canvas?.drawing = previous
        isRestoring = false
        canUndo = !history.isEmpty
        onDrawingChanged?(Self.data(of: previous))
    }

    private static func data(of drawing: PKDrawing) -> Data? {
        drawing.strokes.isEmpty ? nil : drawing.dataRepresentation()
    }

    private func applyTool() {
        canvas?.tool = pkTool
    }
}
