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

    /// One canvas per page being drawn on (change 025: both pages of the spread), by page id.
    @ObservationIgnored private var canvases: [UUID: PKCanvasView] = [:]
    /// Called after each stroke with the page and its drawing data (`nil` = no strokes left). Undo / redo live in the
    /// editor ViewModel for every change (change 025).
    @ObservationIgnored var onDrawingChanged: ((UUID, Data?) -> Void)?
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

    func attach(_ canvas: PKCanvasView, drawing: PKDrawing, pageID: UUID) {
        canvases[pageID] = canvas
        isRestoring = true
        canvas.drawing = drawing
        isRestoring = false
        canvas.tool = pkTool
    }

    /// A friend's strokes, or undo / redo: the canvas shows the stored drawing without reporting a change.
    func replaceDrawing(_ drawing: PKDrawing, pageID: UUID) {
        isRestoring = true
        canvases[pageID]?.drawing = drawing
        isRestoring = false
    }

    func detach(pageID: UUID, canvas: PKCanvasView) {
        if canvases[pageID] === canvas { canvases[pageID] = nil }
    }

    func drawingDidChange(_ drawing: PKDrawing, pageID: UUID) {
        guard !isRestoring else { return }
        showsSizePanel = false
        onDrawingChanged?(pageID, Self.data(of: drawing))
    }

    private static func data(of drawing: PKDrawing) -> Data? {
        drawing.strokes.isEmpty ? nil : drawing.dataRepresentation()
    }

    private func applyTool() {
        let tool = pkTool
        for canvas in canvases.values { canvas.tool = tool }
    }
}
