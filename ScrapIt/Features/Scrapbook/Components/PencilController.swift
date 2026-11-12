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

    /// The canvases being drawn on (change 025: both pages of the spread; change 104: one canvas over both).
    @ObservationIgnored private var boards: [Board] = []
    /// Called after each stroke with the pages it changed and their drawing data (`nil` = no strokes left). Undo /
    /// redo live in the editor ViewModel for every change (change 025).
    @ObservationIgnored var onDrawingChanged: (([UUID: Data?]) -> Void)?
    @ObservationIgnored private var isRestoring = false

    /// A canvas and the pages under it, left to right, each one `pageWidth` wide in the drawing space (change 104).
    /// A stroke belongs to the page it starts on and is stored in that page's own drawing space.
    private struct Board {
        let canvas: PKCanvasView
        let pageIDs: [UUID]
        let pageWidth: CGFloat
        /// Each page's last drawing, so only the pages a stroke changed are reported.
        var pageData: [Data?]
    }

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

    /// `drawings`: one per page in `pageIDs`, in each page's own drawing space.
    func attach(_ canvas: PKCanvasView, pageIDs: [UUID], drawings: [PKDrawing], pageWidth: CGFloat) {
        boards.removeAll { $0.canvas === canvas }
        boards.append(Board(canvas: canvas, pageIDs: pageIDs, pageWidth: pageWidth, pageData: []))
        replaceDrawings(drawings, canvas: canvas)
        canvas.tool = pkTool
    }

    /// A friend's strokes, or undo / redo: the canvas shows the stored drawings without reporting a change.
    func replaceDrawings(_ drawings: [PKDrawing], canvas: PKCanvasView) {
        guard let index = boards.firstIndex(where: { $0.canvas === canvas }) else { return }
        let merged = Self.merged(drawings, pageWidth: boards[index].pageWidth)
        isRestoring = true
        canvas.drawing = merged
        isRestoring = false
        boards[index].pageData = Self.split(merged, pageCount: drawings.count, pageWidth: boards[index].pageWidth)
            .map(Self.data(of:))
    }

    func detach(canvas: PKCanvasView) {
        boards.removeAll { $0.canvas === canvas }
    }

    func drawingDidChange(_ drawing: PKDrawing, canvas: PKCanvasView) {
        guard !isRestoring, let index = boards.firstIndex(where: { $0.canvas === canvas }) else { return }
        showsSizePanel = false
        let board = boards[index]
        let pageData = Self.split(drawing, pageCount: board.pageIDs.count, pageWidth: board.pageWidth).map(Self.data(of:))
        var changes: [UUID: Data?] = [:]
        for (offset, pageID) in board.pageIDs.enumerated() where pageData[offset] != board.pageData[offset] {
            changes[pageID] = pageData[offset]
        }
        boards[index].pageData = pageData
        if !changes.isEmpty { onDrawingChanged?(changes) }
    }

    /// The pages' drawings side by side: page `i` shifted right by `i` page widths.
    static func merged(_ drawings: [PKDrawing], pageWidth: CGFloat) -> PKDrawing {
        var strokes: [PKStroke] = []
        for (offset, drawing) in drawings.enumerated() {
            strokes += drawing.strokes.map { shifted($0, by: CGFloat(offset) * pageWidth) }
        }
        return PKDrawing(strokes: strokes)
    }

    /// Back to one drawing per page: each stroke goes to the page its first point is on, in that page's space.
    static func split(_ drawing: PKDrawing, pageCount: Int, pageWidth: CGFloat) -> [PKDrawing] {
        var strokes = Array(repeating: [PKStroke](), count: pageCount)
        for stroke in drawing.strokes {
            let startX = stroke.path.first.map { $0.location.applying(stroke.transform).x } ?? 0
            let page = pageCount > 1 ? min(max(Int((startX / pageWidth).rounded(.down)), 0), pageCount - 1) : 0
            strokes[page].append(shifted(stroke, by: -CGFloat(page) * pageWidth))
        }
        return strokes.map { PKDrawing(strokes: $0) }
    }

    private static func shifted(_ stroke: PKStroke, by x: CGFloat) -> PKStroke {
        guard x != 0 else { return stroke }
        var stroke = stroke
        stroke.transform = stroke.transform.concatenating(CGAffineTransform(translationX: x, y: 0))
        return stroke
    }

    private static func data(of drawing: PKDrawing) -> Data? {
        drawing.strokes.isEmpty ? nil : drawing.dataRepresentation()
    }

    private func applyTool() {
        let tool = pkTool
        for board in boards { board.canvas.tool = tool }
    }
}
