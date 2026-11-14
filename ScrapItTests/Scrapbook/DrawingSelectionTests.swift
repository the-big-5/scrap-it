import CoreGraphics
import Foundation
import PencilKit
import SwiftData
import Testing
@testable import ScrapIt

/// Selecting a pencil drawing and moving, resizing, rotating or removing it (change 150).
@MainActor
struct DrawingSelectionTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let scrapbook: Scrapbook

    init() throws {
        container = try ModelContainer(
            for: ScrapIt.schema,
            configurations: ModelConfiguration(UUID().uuidString, schema: ScrapIt.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        scrapbook = Scrapbook(title: "Bali '27", sourceSessionID: UUID())
        context.insert(scrapbook)
        try context.save()
    }

    /// A straight line in drawing space (600 × 800).
    private func line(from start: CGPoint, to end: CGPoint) -> PKStroke {
        let points = [start, end].enumerated().map { index, location in
            PKStrokePoint(location: location, timeOffset: Double(index) * 0.1, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    /// Two strokes forming one shape at the top left, one far away at the bottom right.
    private var sample: PKDrawing {
        PKDrawing(strokes: [
            line(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 50)),
            line(from: CGPoint(x: 160, y: 60), to: CGPoint(x: 160, y: 150)),
            line(from: CGPoint(x: 450, y: 650), to: CGPoint(x: 550, y: 650)),
        ])
    }

    // MARK: - Geometry

    @Test func aTapFindsTheStrokeUnderIt() {
        #expect(DrawingSelectionGeometry.strokeIndex(at: CGPoint(x: 500, y: 652), in: sample, tolerance: 10) == 2)
        #expect(DrawingSelectionGeometry.strokeIndex(at: CGPoint(x: 300, y: 400), in: sample, tolerance: 10) == nil)
    }

    @Test func nearbyStrokesAreOneDrawing() {
        #expect(DrawingSelectionGeometry.cluster(from: 0, in: sample) == [0, 1])
        #expect(DrawingSelectionGeometry.cluster(from: 1, in: sample) == [0, 1])
        #expect(DrawingSelectionGeometry.cluster(from: 2, in: sample) == [2])
    }

    @Test func strokesFurtherThanTheGapStaySeparate() {
        let drawing = PKDrawing(strokes: [
            line(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 50)),
            line(from: CGPoint(x: 250, y: 50), to: CGPoint(x: 350, y: 50)),
        ])
        #expect(DrawingSelectionGeometry.cluster(from: 0, in: drawing) == [0])
    }

    @Test func aTransformMovesOnlyTheChosenStrokes() {
        let moved = DrawingSelectionGeometry.applying(CGAffineTransform(translationX: 100, y: 20), to: [0, 1], in: sample)
        #expect(moved.strokes[0].transform == CGAffineTransform(translationX: 100, y: 20))
        #expect(moved.strokes[1].transform == CGAffineTransform(translationX: 100, y: 20))
        #expect(moved.strokes[2].transform == .identity)
    }

    @Test func scaleAndRotationKeepTheCenterInPlace() {
        let center = CGPoint(x: 100, y: 100)
        let transform = DrawingSelectionGeometry.transform(translation: .zero, scale: 2, rotation: .pi / 2, around: center)
        let mapped = center.applying(transform)
        #expect(abs(mapped.x - center.x) < 0.001 && abs(mapped.y - center.y) < 0.001)
        let corner = CGPoint(x: 110, y: 100).applying(transform)
        #expect(abs(corner.x - 100) < 0.001 && abs(corner.y - 120) < 0.001)
    }

    @Test func removingLeavesTheOtherStrokes() {
        let rest = DrawingSelectionGeometry.removing([0, 1], from: sample)
        #expect(rest.strokes.count == 1)
        #expect(rest.strokes[0].renderBounds.minX > 400)
    }

    // MARK: - Editor

    /// An editor on the two-page view, with `sample` drawn on the left page. Page shown at 300 × 400.
    private func makeEditor(realtime: MockScrapbookRealtimeService? = nil) throws -> (ScrapbookViewModel, UUID) {
        let vm = ScrapbookViewModel(modelContext: context, sessionStore: SessionStore(modelContext: context),
                                    scrapbookID: scrapbook.id, realtimeService: realtime)
        vm.openSpread()
        let pageID = try #require(vm.currentSpreadPages.first?.id)
        vm.selectTrayTool(.pencil)
        vm.updateDrawings([pageID: sample.dataRepresentation()])
        vm.closeTray()
        return (vm, pageID)
    }

    private let pageSize = CGSize(width: 300, height: 400)

    private func strokes(of vm: ScrapbookViewModel, page: UUID) throws -> [PKStroke] {
        let layer = try #require(vm.currentSpreadPages.first { $0.id == page }?.sortedItems.first { $0.kind == .drawing })
        return try PKDrawing(data: try #require(layer.drawingData)).strokes
    }

    @Test func tappingAStrokePicksItsDrawingAndEmptyPaperLetsGo() throws {
        let (vm, pageID) = try makeEditor()
        // (100, 50) in drawing space is (50, 25) on a page shown 400 pt high.
        vm.tapPaper(pageID: pageID, at: CGPoint(x: 50, y: 25), pageSize: pageSize, displayScale: 1)
        let selection = try #require(vm.drawingSelection)
        #expect(selection.strokes == [0, 1])
        vm.tapPaper(pageID: pageID, at: CGPoint(x: 150, y: 200), pageSize: pageSize, displayScale: 1)
        #expect(vm.drawingSelection == nil)
    }

    @Test func noDrawingIsPickedWhileATrayToolIsOn() throws {
        let (vm, pageID) = try makeEditor()
        vm.selectTrayTool(.pencil)
        vm.tapPaper(pageID: pageID, at: CGPoint(x: 50, y: 25), pageSize: pageSize, displayScale: 1)
        #expect(vm.drawingSelection == nil)
    }

    @Test func movingADrawingIsOneUndoStepAndIsShared() async throws {
        let realtime = MockScrapbookRealtimeService()
        let (vm, pageID) = try makeEditor(realtime: realtime)
        await vm.connectRealtime()
        vm.tapPaper(pageID: pageID, at: CGPoint(x: 50, y: 25), pageSize: pageSize, displayScale: 1)
        // 10 page points = 20 drawing units.
        vm.commitDrawingTransform(translation: CGSize(width: 10, height: 0), scale: 1, rotation: 0)
        let moved = try strokes(of: vm, page: pageID)
        #expect(moved[0].transform == CGAffineTransform(translationX: 20, y: 0))
        #expect(moved[2].transform == .identity)
        #expect(vm.drawingSelection != nil)
        try await Task.sleep(for: .milliseconds(100))
        let update = realtime.broadcastedEvents.last { $0.type == .drawingUpdated }
        #expect(try PKDrawing(data: try #require(update?.drawingData)).strokes[0].transform == moved[0].transform)

        vm.undo()
        #expect(try strokes(of: vm, page: pageID).allSatisfy { $0.transform == .identity })
        #expect(vm.drawingSelection == nil)
    }

    @Test func aSmallTurnSnapsStraight() throws {
        let (vm, pageID) = try makeEditor()
        vm.tapPaper(pageID: pageID, at: CGPoint(x: 50, y: 25), pageSize: pageSize, displayScale: 1)
        vm.commitDrawingTransform(translation: .zero, scale: 1, rotation: 0.02)
        #expect(try strokes(of: vm, page: pageID).allSatisfy { $0.transform == .identity })
    }

    @Test func removingADrawingKeepsTheRestAndUndoBringsItBack() throws {
        let (vm, pageID) = try makeEditor()
        vm.tapPaper(pageID: pageID, at: CGPoint(x: 50, y: 25), pageSize: pageSize, displayScale: 1)
        vm.removeSelectedDrawing()
        #expect(try strokes(of: vm, page: pageID).count == 1)
        #expect(vm.drawingSelection == nil)
        vm.undo()
        #expect(try strokes(of: vm, page: pageID).count == 3)
    }

    @Test func aFriendsDrawingUpdateLetsTheSelectionGo() async throws {
        let realtime = MockScrapbookRealtimeService()
        let (vm, pageID) = try makeEditor(realtime: realtime)
        await vm.connectRealtime()
        vm.tapPaper(pageID: pageID, at: CGPoint(x: 50, y: 25), pageSize: pageSize, displayScale: 1)
        let layerID = try #require(vm.drawingSelection?.layerID)
        realtime.simulateIncomingEvent(ScrapbookEvent(type: .drawingUpdated, pageIndex: 0, senderID: "peer",
                                                      itemID: layerID, drawingData: sample.dataRepresentation()))
        #expect(vm.drawingSelection == nil)
    }
}
