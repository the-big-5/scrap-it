import CoreGraphics
import Foundation
import PencilKit
import Testing
@testable import ScrapIt

/// Pencil on the two-page view: one canvas over both pages, each stroke stored on the page it starts on (change 104).
struct PencilControllerTests {
    @Test func aSpreadStrokeBelongsToThePageItStartsOn() {
        func stroke(from start: CGFloat, to end: CGFloat) -> PKStroke {
            let points = [start, end].map {
                PKStrokePoint(location: CGPoint(x: $0, y: 100), timeOffset: 0, size: CGSize(width: 4, height: 4),
                              opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
        }
        // Spread space: the left page is 0–600, the right page 600–1200.
        let drawing = PKDrawing(strokes: [stroke(from: 500, to: 700), stroke(from: 650, to: 550)])
        let pages = PencilController.split(drawing, pageCount: 2, pageWidth: 600)

        // Started on the left: stays on the left, reaching past its right edge.
        #expect(pages[0].strokes.count == 1)
        let leftReach: CGFloat = pages[0].bounds.maxX
        #expect(abs(leftReach - 700) < 5)
        // Started on the right: on the right page in its own space, reaching past its left edge.
        #expect(pages[1].strokes.count == 1)
        let rightReach: CGFloat = pages[1].bounds.minX
        #expect(abs(rightReach + 50) < 5)

        // Merging back puts every stroke where it was drawn.
        let merged = PencilController.merged(pages, pageWidth: 600)
        let minShift: CGFloat = merged.bounds.minX - drawing.bounds.minX
        let maxShift: CGFloat = merged.bounds.maxX - drawing.bounds.maxX
        #expect(abs(minShift) < 0.01)
        #expect(abs(maxShift) < 0.01)
    }

    @Test func mergedDrawingDataCombinesAllStrokes() throws {
        func stroke(x: CGFloat) -> PKStroke {
            let points = [x, x + 20].map {
                PKStrokePoint(location: CGPoint(x: $0, y: 50), timeOffset: 0, size: CGSize(width: 4, height: 4),
                              opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
        }
        let d1 = PKDrawing(strokes: [stroke(x: 10)]).dataRepresentation()
        let d2 = PKDrawing(strokes: [stroke(x: 100)]).dataRepresentation()
        let merged = PencilController.mergedDrawingData([d1, Data(), d2])
        let decoded = try PKDrawing(data: merged)
        #expect(decoded.strokes.count == 2)
    }
}
