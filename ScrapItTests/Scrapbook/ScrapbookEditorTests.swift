import CloudKit
import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import ScrapIt

private final class EditorNavigator: Navigator {
    var selectedTab: AppTab = .home
    var path: [AppRoute] = []
    var isTabBarHidden = false
    var cameraReturnPhase: CameraReturnPhase = .idle
    var cameraReturnAngle: Double = 0.0
}

@MainActor
struct ScrapbookEditorTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let sessionID = UUID()
    let scrapbook: Scrapbook
    let stillPhoto: ScrapPhoto
    let livePhoto: ScrapPhoto
    private let navigator = EditorNavigator()

    init() throws {
        container = try ModelContainer(
            for: ScrapIt.schema,
            // Unique name: the test host app already uses the "default" and "Rolls" stores.
            configurations: ModelConfiguration(UUID().uuidString, schema: ScrapIt.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        scrapbook = Scrapbook(title: "Bali '27", sourceSessionID: sessionID)
        stillPhoto = ScrapPhoto(imageData: Data("still".utf8), authorID: "host-1", authorName: "Nabiel",
                                timestamp: Date(timeIntervalSince1970: 100), sourceSessionID: sessionID)
        livePhoto = ScrapPhoto(imageData: Data("live".utf8), livePhotoMovieData: Data("mov".utf8),
                               authorID: "guest-2", authorName: "Brian",
                               timestamp: Date(timeIntervalSince1970: 200), sourceSessionID: sessionID)
        context.insert(scrapbook)
        context.insert(stillPhoto)
        context.insert(livePhoto)
        scrapbook.photos = [stillPhoto, livePhoto]
        try context.save()
    }

    private func makeEditor() -> ScrapbookViewModel {
        ScrapbookViewModel(
            modelContext: context,
            navigator: navigator,
            sessionStore: SessionStore(modelContext: context),
            scrapbookID: scrapbook.id
        )
    }

    // MARK: - Pages

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    @Test func newScrapbookStartsWithOneEmptySpread() {
        let vm = makeEditor()
        #expect(vm.pages.count == 2)
        #expect(vm.spreadCount == 1)
        #expect(vm.mode == .book)
        #expect(vm.currentPage?.id == vm.leftPage?.id)
        #expect(vm.currentPage?.allItems.isEmpty == true)
    }

    @Test func anOddPageCountGetsOneMorePage() throws {
        for order in 0..<3 {
            let page = ScrapbookPage(order: order)
            context.insert(page)
            page.scrapbook = scrapbook
        }
        try context.save()
        let vm = makeEditor()
        #expect(vm.pages.count == 4)
        #expect(vm.spreads.map(\.count) == [2, 2])
    }

    @Test func swipingPastTheLastSpreadAddsTwoEmptyPages() {
        let vm = makeEditor()
        let first = vm.currentSpreadPages.map(\.id)
        vm.swipeSpread(by: -1)
        #expect(vm.spreadIndex == 0)

        vm.swipeSpread(by: 1)
        #expect(vm.pages.count == 4)
        #expect(vm.spreadIndex == 1)
        #expect(vm.currentPage?.id == vm.leftPage?.id)
        #expect(!first.contains(vm.leftPage?.id ?? UUID()))

        vm.swipeSpread(by: -1)
        #expect(vm.spreadIndex == 0)
        #expect(vm.currentSpreadPages.map(\.id) == first)
        #expect(vm.pages.count == 4)
    }

    // MARK: - Photos

    @Test func photoTrayOffersOnlyThisRollsPhotosNewestFirst() {
        let other = ScrapPhoto(imageData: Data(), authorID: "x", authorName: "X", sourceSessionID: UUID())
        context.insert(other)
        let vm = makeEditor()

        #expect(vm.trayPhotos.map(\.id) == [livePhoto.id, stillPhoto.id])
        #expect(vm.addPhoto(stillPhoto.id))
        #expect(!vm.addPhoto(other.id))
        #expect(vm.addPhoto(livePhoto.id))

        #expect(vm.currentPage?.allItems.compactMap(\.photoID).sorted { $0.uuidString < $1.uuidString }
                == [stillPhoto.id, livePhoto.id].sorted { $0.uuidString < $1.uuidString })
        let live = vm.currentPage?.allItems.first { $0.photoID == livePhoto.id }
        #expect(live.map(vm.isLive) == true)
    }

    @Test func aPageHoldsAtMostFortyItems() throws {
        let vm = makeEditor()
        let letter = try #require(LetterCatalog.letters.first)
        #expect(ScrapbookPage.maxItems == 40)
        for _ in 0..<ScrapbookPage.maxItems {
            vm.addLetter(letter)
        }
        #expect(vm.currentPage?.allItems.count == ScrapbookPage.maxItems)
        #expect(vm.remainingSlots == 0)

        #expect(!vm.addPhoto(livePhoto.id))
        #expect(!vm.addLetter(letter))
        #expect(vm.currentPage?.allItems.count == ScrapbookPage.maxItems)
        #expect(vm.toastMessage == ScrapbookViewModel.pageFullMessage)
    }

    @Test func reduceMotionAddsLivePhotosWithMotionOff() throws {
        let vm = makeEditor()
        vm.addPhoto(livePhoto.id, reduceMotion: true)
        let item = try #require(vm.currentPage?.allItems.first)
        #expect(!item.loopEnabled)
        vm.toggleMotion(item.id)
        #expect(item.loopEnabled)
    }

    // MARK: - Arranging

    @Test func transformIsClampedAndRotationSnaps() throws {
        let vm = makeEditor()
        vm.addPhoto(stillPhoto.id)
        let item = try #require(vm.currentPage?.allItems.first)
        item.rotation = 0

        vm.commitTransform(itemID: item.id, translation: CGSize(width: 10_000, height: -10_000), scale: 0.01,
                           rotationDelta: 2 * .pi / 180, pageSize: CGSize(width: 300, height: 400))

        #expect(item.centerX == 1)
        #expect(item.centerY == 0)
        #expect(item.width == ScrapbookItem.minWidth)
        #expect(item.rotation == 0)
    }

    @Test func selectingAnItemBringsItToTheFront() throws {
        let vm = makeEditor()
        vm.addPhoto(stillPhoto.id)
        vm.addPhoto(livePhoto.id)
        let back = try #require(vm.currentPage?.sortedItems.first)

        vm.selectItem(back.id)

        #expect(vm.selectedItemID == back.id)
        #expect(vm.currentPage?.sortedItems.last?.id == back.id)
    }

    // MARK: - Scissors

    @Test func cuttingSplitsAPhotoAndUndoRestoresIt() throws {
        let vm = makeEditor()
        vm.addPhoto(stillPhoto.id)
        let item = try #require(vm.currentPage?.allItems.first)
        item.centerX = 0.5
        item.centerY = 0.5
        item.rotation = 0
        let size = CGSize(width: 300, height: 400)

        let didCut = vm.cut(along: [CGPoint(x: 0, y: 200), CGPoint(x: 150, y: 201), CGPoint(x: 300, y: 200)], pageSize: size)

        #expect(didCut)
        #expect(vm.currentPage?.allItems.count == 2)
        #expect(vm.currentPage?.allItems.allSatisfy { $0.maskPolygon != nil } == true)
        #expect(vm.canUndo)

        vm.undo()

        #expect(vm.currentPage?.allItems.map(\.id) == [item.id])
        #expect(item.maskPolygon == nil)
        #expect(item.centerX == 0.5)
        #expect(vm.canRedo)

        vm.redo()
        #expect(vm.currentPage?.allItems.count == 2)
    }

    @Test func strokeOutsideAPhotoCutsNothing() {
        let vm = makeEditor()
        vm.addPhoto(stillPhoto.id)
        let didCut = vm.cut(along: [CGPoint(x: 0, y: 2), CGPoint(x: 300, y: 2)], pageSize: CGSize(width: 300, height: 400))
        #expect(!didCut)
        #expect(vm.currentPage?.allItems.count == 1)
    }

    @Test func cutGeometrySplitsTheUnitSquareInTwo() throws {
        let pieces = try #require(CutGeometry.splitAll(
            CutGeometry.unitSquare, by: [CGPoint(x: -0.1, y: 0.5), CGPoint(x: 1.1, y: 0.5)], minimumArea: 0.02
        ))
        #expect(pieces.count == 2)
        #expect(abs(pieces.map(CutGeometry.area).reduce(0, +) - 1) < 0.001)
    }

    // MARK: - Stickers

    @Test func aStickerCanBeUsedOncePerSheet() throws {
        let vm = makeEditor()
        vm.toggleStickerSheet(StickerCatalog.travel)
        #expect(vm.isStickerSheetOpen)
        let sticker = try #require(vm.stickerSet.stickers.first)
        let pageFrame = CGRect(x: 0, y: 100, width: 300, height: 400)

        #expect(vm.placeSticker(sticker, center: CGPoint(x: 150, y: 300), width: 60, rotation: 0, pageFrame: pageFrame))
        #expect(!vm.placeSticker(sticker, center: CGPoint(x: 150, y: 300), width: 60, rotation: 0, pageFrame: pageFrame))

        let placed = try #require(vm.currentPage?.allItems.first)
        #expect(placed.stickerID == sticker.id)
        #expect(placed.centerX == 0.5)
        #expect(placed.centerY == 0.5)
        #expect(vm.currentStickerSheet?.remainingCount(in: vm.stickerSet) == vm.stickerSet.stickers.count - 1)

        vm.takeNewStickerSheet()
        #expect(vm.placeSticker(sticker, center: CGPoint(x: 100, y: 200), width: 60, rotation: 0, pageFrame: pageFrame))
    }

    @Test func funStickersHaveTheirOwnSheet() throws {
        let vm = makeEditor()
        #expect(StickerCatalog.fun.stickers.count == 27)
        vm.toggleStickerSheet(StickerCatalog.fun)
        let sticker = try #require(StickerCatalog.fun.stickers.first)
        let pageFrame = CGRect(x: 0, y: 0, width: 300, height: 400)

        #expect(vm.placeSticker(sticker, center: CGPoint(x: 150, y: 200), width: 60, rotation: 0, pageFrame: pageFrame))

        #expect(vm.existingSheet(for: StickerCatalog.fun)?.usedStickerIDs == [sticker.id])
        #expect(vm.existingSheet(for: StickerCatalog.travel) == nil)
        vm.toggleStickerSheet(StickerCatalog.fun)
        #expect(!vm.isStickerSheetOpen)
    }

    // MARK: - Tray

    @Test func trayToolsOpenTheirSecondTrayAndCloseWithTheTray() {
        let vm = makeEditor()
        vm.openTray()
        vm.selectTrayTool(.photo)
        #expect(vm.activeTool == .photo)
        vm.selectTrayTool(.photo)
        #expect(vm.activeTool == nil)

        vm.selectTrayTool(.letters)
        vm.selectTrayTool(.scissors)
        #expect(vm.isCutting)
        #expect(vm.activeTool == nil)
        #expect(vm.raisedTool == .scissors)

        vm.selectTrayTool(.washi)
        #expect(!vm.isCutting)
        vm.tapEmptyPage()
        #expect(vm.activeTool == nil)

        vm.selectTrayTool(.sticker)
        vm.closeTray()
        #expect(!vm.isTrayOpen)
        #expect(vm.activeTool == nil)
    }

    @Test func toolHintsShowOncePerScrapbook() throws {
        let vm = makeEditor()
        vm.selectTrayTool(.scissors)
        #expect(vm.hintTool == .scissors)
        vm.selectTrayTool(.scissors)
        #expect(vm.hintTool == nil)
        vm.selectTrayTool(.scissors)
        #expect(vm.hintTool == nil)

        vm.selectTrayTool(.washi)
        vm.selectWashi(try #require(WashiCatalog.styles.first))
        #expect(vm.hintTool == .washi)
        vm.selectTrayTool(.pencil)
        #expect(vm.hintTool == .pencil)
        vm.selectTrayTool(.pencil)

        let reopened = makeEditor()
        reopened.selectTrayTool(.pencil)
        #expect(reopened.hintTool == nil)
        #expect(Set(scrapbook.shownToolHints) == ["scissors", "washi", "pencil"])

        let other = Scrapbook(title: "Other")
        context.insert(other)
        let otherEditor = ScrapbookViewModel(modelContext: context, sessionStore: SessionStore(modelContext: context),
                                             scrapbookID: other.id)
        otherEditor.selectTrayTool(.scissors)
        #expect(otherEditor.hintTool == .scissors)
    }

    @Test func pencilHintMentionsApplePencilOnlyOnIPad() {
        #expect(ScrapbookTool.pencil.hint(isPad: false) == "Draw with your finger.")
        #expect(ScrapbookTool.pencil.hint(isPad: true) == "Draw with your finger or Apple Pencil.")
        #expect(ScrapbookTool.washi.hint(isPad: false) == ScrapbookTool.washi.hint(isPad: true))
    }

    // MARK: - Items

    @Test func itemKindComesFromTheFilledField() {
        let item = ScrapbookItem(centerX: 0.5, centerY: 0.5, width: 0.5, rotation: 0, zIndex: 0)
        #expect(item.kind == .photo)
        item.washiID = "washi.waves"
        #expect(item.kind == .washi)
        item.text = "Hi"
        #expect(item.kind == .text)
        item.letterID = "letter.A"
        #expect(item.kind == .letter)
        item.stickerID = "travel.airplane"
        #expect(item.kind == .sticker)
        item.drawingData = Data()
        #expect(item.kind == .drawing)
    }

    @Test func widthLimitsDependOnTheKind() throws {
        let vm = makeEditor()
        let letter = try #require(LetterCatalog.letter(withID: "letter.A"))
        vm.addLetter(letter)
        let item = try #require(vm.currentPage?.allItems.first)
        let size = CGSize(width: 300, height: 400)

        vm.commitTransform(itemID: item.id, translation: .zero, scale: 0.01, rotationDelta: 0, pageSize: size)
        #expect(item.width == 0.04)

        item.letterID = nil
        item.washiID = "washi.waves"
        vm.commitTransform(itemID: item.id, translation: .zero, scale: 100, rotationDelta: 0, pageSize: size)
        #expect(item.width == 1.6)
    }

    @Test func tappedLettersLineUpAndWrap() throws {
        let vm = makeEditor()
        let letter = try #require(LetterCatalog.letter(withID: "letter.W"))
        let start = Date(timeIntervalSince1970: 1_000)

        vm.addLetter(letter, now: start)
        vm.addLetter(letter, now: start.addingTimeInterval(1))
        let placed = try #require(vm.currentPage?.sortedItems)
        #expect(placed.count == 2)
        #expect(placed[1].centerX > placed[0].centerX)
        #expect(placed[1].centerY == placed[0].centerY)

        for index in 2..<20 {
            vm.addLetter(letter, now: start.addingTimeInterval(1 + Double(index) * 0.1))
        }
        let all = try #require(vm.currentPage?.sortedItems)
        #expect(all.allSatisfy { $0.centerX + $0.width / 2 <= 0.97 })
        #expect(Set(all.map(\.centerY)).count > 1)

        // After 3 s a letter starts again at the left.
        vm.addLetter(letter, now: start.addingTimeInterval(30))
        let last = try #require(vm.currentPage?.sortedItems.last)
        #expect(abs(last.centerX - (0.12 + last.width / 2)) < 0.0001)
        #expect(last.centerY == 0.35)
        #expect(last.letterID == letter.id)
    }

    @Test func washiShorterThanTheMinimumIsCancelled() throws {
        let vm = makeEditor()
        let size = CGSize(width: 300, height: 400)
        vm.selectTrayTool(.washi)
        vm.selectWashi(try #require(WashiCatalog.style(withID: "washi.waves")))

        #expect(!vm.addWashi(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 100), seed: 7, pageSize: size))
        #expect(vm.addWashi(from: CGPoint(x: 0, y: 200), to: CGPoint(x: 150, y: 200), seed: 7, pageSize: size))

        let tape = try #require(vm.currentPage?.allItems.first)
        #expect(vm.currentPage?.allItems.count == 1)
        #expect(tape.kind == .washi)
        #expect(tape.washiLength == 0.5)
        #expect(tape.tearSeed == 7)
        #expect(tape.centerX == 0.25)
        #expect(tape.rotation == 0)
    }

    @Test func textIsAddedEditedAndClearedAway() throws {
        let vm = makeEditor()
        vm.selectTrayTool(.text)
        #expect(vm.textEditor == TextEditorState())
        vm.textEditor?.draft = "   "
        vm.commitTextEditor()
        #expect(vm.currentPage?.allItems.isEmpty == true)

        vm.selectTrayTool(.text)
        vm.textEditor?.draft = "  Bali  "
        vm.textEditor?.color = .pink
        vm.commitTextEditor()
        let item = try #require(vm.currentPage?.allItems.first)
        #expect(item.text == "Bali")
        #expect(item.textColor == "pink")
        #expect(item.width == TextItemStyle.defaultSize)
        #expect(item.centerY == 0.4)

        vm.doubleTapItem(item.id)
        #expect(vm.textEditor?.draft == "Bali")
        vm.textEditor?.draft = "Ubud"
        vm.commitTextEditor()
        #expect(item.text == "Ubud")

        vm.editText(item.id)
        vm.textEditor?.draft = ""
        vm.commitTextEditor()
        #expect(vm.currentPage?.allItems.isEmpty == true)
    }

    @Test func doubleTapOpensAPhotoFullScreen() throws {
        let vm = makeEditor()
        vm.addPhoto(livePhoto.id)
        let item = try #require(vm.currentPage?.allItems.first)
        vm.doubleTapItem(item.id)
        #expect(vm.viewerPhoto?.id == livePhoto.id)
        vm.closePhotoViewer()
        #expect(vm.viewerPhoto == nil)
    }

    @Test func allToolbarToolsAreSharedWithFriends() async throws {
        let realtime = MockScrapbookRealtimeService()
        let vm = ScrapbookViewModel(modelContext: context, sessionStore: SessionStore(modelContext: context),
                                    scrapbookID: scrapbook.id, realtimeService: realtime)
        let pageFrame = CGRect(x: 0, y: 0, width: 300, height: 400)
        vm.addPhoto(stillPhoto.id)
        vm.addLetter(try #require(LetterCatalog.letters.first))
        vm.selectTrayTool(.text)
        vm.textEditor?.draft = "Hi"
        vm.commitTextEditor()
        vm.selectTrayTool(.washi)
        vm.selectWashi(try #require(WashiCatalog.styles.first))
        _ = vm.addWashi(from: .zero, to: CGPoint(x: 200, y: 0), seed: 1, pageSize: pageFrame.size)
        _ = vm.placeSticker(try #require(StickerCatalog.travel.stickers.first), center: CGPoint(x: 100, y: 100),
                            width: 60, rotation: 0, pageFrame: pageFrame)
        _ = vm.placeSticker(try #require(StickerCatalog.fun.stickers.first), center: CGPoint(x: 100, y: 100),
                            width: 60, rotation: 0, pageFrame: pageFrame)
        vm.selectTrayTool(.pencil)
        let drawingID = try #require(vm.activeDrawingID)
        vm.updateActiveDrawing(Data("strokes".utf8))
        vm.selectTrayTool(.pencil)
        for item in vm.currentPage?.allItems ?? [] {
            vm.bringToFront(item.id)
        }
        try await Task.sleep(for: .milliseconds(100))

        let placed = realtime.broadcastedEvents.filter { $0.type == .itemPlaced }.compactMap(\.item)
        // Pencil opens a layer on both pages of the spread (change 025); the right page's stays empty and is removed.
        #expect(placed.count == 8)
        let emptyLayer = try #require(placed.first { $0.drawingData != nil && $0.id != drawingID })
        #expect(realtime.broadcastedEvents.contains { $0.type == .itemRemoved && $0.itemID == emptyLayer.id })
        #expect(placed.contains { $0.photoID == stillPhoto.id })
        #expect(placed.contains { $0.letterID == LetterCatalog.letters.first?.id })
        #expect(placed.contains { $0.text == "Hi" })
        #expect(placed.contains { $0.washiID == WashiCatalog.styles.first?.id })
        #expect(placed.contains { $0.stickerID == StickerCatalog.travel.stickers.first?.id })
        #expect(placed.contains { $0.stickerID == StickerCatalog.fun.stickers.first?.id })
        #expect(placed.contains { $0.id == drawingID })
        #expect(realtime.broadcastedEvents.filter { $0.type == .itemTransformed }.count == 7)
        let drawingUpdate = realtime.broadcastedEvents.last { $0.type == .drawingUpdated }
        #expect(drawingUpdate?.itemID == drawingID)
        #expect(drawingUpdate?.drawingData == Data("strokes".utf8))
    }

    @Test func photoTrayHidesPlacedPhotosAcrossPagesUntilAllPiecesAreDeleted() throws {
        let emptyBook = Scrapbook(title: "Empty", sourceSessionID: UUID())
        context.insert(emptyBook)
        let emptyVM = ScrapbookViewModel(
            modelContext: context,
            navigator: navigator,
            sessionStore: SessionStore(modelContext: context),
            scrapbookID: emptyBook.id
        )
        #expect(emptyVM.emptyPhotoTrayMessage == "Photos from this roll appear here.")

        let vm = makeEditor()
        #expect(vm.trayPhotos.map(\.id) == [livePhoto.id, stillPhoto.id])

        #expect(vm.addPhoto(stillPhoto.id))
        #expect(vm.trayPhotos.map(\.id) == [livePhoto.id])
        #expect(!vm.addPhoto(stillPhoto.id))

        #expect(vm.addPhoto(livePhoto.id, at: CGPoint(x: 0.15, y: 0.15)))
        #expect(vm.trayPhotos.isEmpty)
        #expect(vm.emptyPhotoTrayMessage == "All photos from this roll are on the scrapbook.")

        // Single-use slot applies across all pages in the scrapbook.
        let firstPage = try #require(vm.pages.first)
        vm.swipeSpread(by: 1)
        #expect(vm.trayPhotos.isEmpty)
        vm.swipeSpread(by: -1)
        vm.currentPageID = firstPage.id

        let placedStill = try #require(vm.currentPage?.allItems.first { $0.photoID == stillPhoto.id })
        placedStill.centerX = 0.5
        placedStill.centerY = 0.5
        placedStill.rotation = 0
        let pageSize = CGSize(width: 300, height: 400)
        #expect(vm.cut(along: [CGPoint(x: 0, y: 200), CGPoint(x: 150, y: 201), CGPoint(x: 300, y: 200)], pageSize: pageSize))
        let pieces = vm.currentPage?.allItems.filter { $0.photoID == stillPhoto.id } ?? []
        #expect(pieces.count == 2)

        vm.removeItem(pieces[0].id)
        #expect(!vm.trayPhotos.contains { $0.id == stillPhoto.id })

        vm.removeItem(pieces[1].id)
        #expect(vm.trayPhotos.map(\.id) == [stillPhoto.id])
    }

    @Test func stickerSheetSlotsLockAndResetAcrossCollaborators() async throws {
        let realtime = MockScrapbookRealtimeService()
        let vm = ScrapbookViewModel(modelContext: context, sessionStore: SessionStore(modelContext: context),
                                    scrapbookID: scrapbook.id, realtimeService: realtime)
        await vm.connectRealtime()
        let travelSticker = try #require(StickerCatalog.travel.stickers.first)
        let funSticker = try #require(StickerCatalog.fun.stickers.first)

        let remoteTravel = ScrapbookItemPayload(
            id: UUID(), stickerID: travelSticker.id,
            centerX: 0.5, centerY: 0.5, width: 0.2, rotation: 0, zIndex: 1
        )
        realtime.simulateIncomingEvent(ScrapbookEvent(
            type: .itemPlaced, pageIndex: 0, senderID: "peer", item: remoteTravel
        ))

        vm.toggleStickerSheet(StickerCatalog.travel)
        #expect(vm.existingSheet(for: StickerCatalog.travel)?.usedStickerIDs.contains(travelSticker.id) == true)
        #expect(!vm.placeSticker(travelSticker, center: CGPoint(x: 150, y: 200),
                                 width: 60, rotation: 0, pageFrame: CGRect(x: 0, y: 0, width: 300, height: 400)))

        vm.takeNewStickerSheet()
        try await Task.sleep(for: .milliseconds(50))
        #expect(vm.existingSheet(for: StickerCatalog.travel)?.usedStickerIDs.isEmpty == true)
        let resetBroadcast = realtime.broadcastedEvents.last { $0.type == .stickerSheetReset }
        #expect(resetBroadcast?.stickerSetID == StickerCatalog.travel.id)

        vm.toggleStickerSheet(StickerCatalog.fun)
        _ = vm.placeSticker(funSticker, center: CGPoint(x: 150, y: 200),
                            width: 60, rotation: 0, pageFrame: CGRect(x: 0, y: 0, width: 300, height: 400))
        #expect(vm.existingSheet(for: StickerCatalog.fun)?.usedStickerIDs == [funSticker.id])

        realtime.simulateIncomingEvent(ScrapbookEvent(
            type: .stickerSheetReset, pageIndex: 0, senderID: "peer", stickerSetID: StickerCatalog.fun.id
        ))
        #expect(vm.existingSheet(for: StickerCatalog.fun)?.usedStickerIDs.isEmpty == true)
    }

    @Test func textEditsDrawingLayersMotionAndCutUndoSyncRemotely() async throws {
        let realtime = MockScrapbookRealtimeService()
        let vm = ScrapbookViewModel(modelContext: context, sessionStore: SessionStore(modelContext: context),
                                    scrapbookID: scrapbook.id, realtimeService: realtime)
        await vm.connectRealtime()

        // Text edit and clear-to-delete
        vm.selectTrayTool(.text)
        vm.textEditor?.draft = "First"
        vm.commitTextEditor()
        let textItem = try #require(vm.currentPage?.allItems.first { $0.kind == .text })

        vm.editText(textItem.id)
        vm.textEditor?.draft = "Second"
        vm.commitTextEditor()
        try await Task.sleep(for: .milliseconds(50))
        let textUpdated = realtime.broadcastedEvents.last { $0.type == .itemTextUpdated }
        #expect(textUpdated?.itemID == textItem.id)
        #expect(textUpdated?.text == "Second")

        realtime.simulateIncomingEvent(ScrapbookEvent(
            type: .itemTextUpdated, pageIndex: 0, senderID: "peer",
            itemID: textItem.id, text: "Peer Edit", textColor: "#112233"
        ))
        #expect(textItem.text == "Peer Edit")
        #expect(textItem.textColor == "#112233")

        vm.editText(textItem.id)
        vm.textEditor?.draft = "   "
        vm.commitTextEditor()
        try await Task.sleep(for: .milliseconds(50))
        #expect(realtime.broadcastedEvents.contains { $0.type == .itemRemoved && $0.itemID == textItem.id })

        // Active Pencil layer remote LWW update bumps remoteDrawingRevision; empty close removes layer remotely
        vm.selectTrayTool(.pencil)
        let activeLayerID = try #require(vm.activeDrawingID)
        let beforeRevision = vm.remoteDrawingRevision
        realtime.simulateIncomingEvent(ScrapbookEvent(
            type: .drawingUpdated, pageIndex: 0, senderID: "peer",
            itemID: activeLayerID, drawingData: Data("remote-ink".utf8)
        ))
        #expect(vm.remoteDrawingRevision == beforeRevision + 1)
        #expect(vm.activeDrawingData == Data("remote-ink".utf8))
        vm.updateActiveDrawing(nil)
        vm.selectTrayTool(.pencil)
        try await Task.sleep(for: .milliseconds(50))
        #expect(realtime.broadcastedEvents.contains { $0.type == .itemRemoved && $0.itemID == activeLayerID })

        // Live photo loop toggle
        vm.addPhoto(livePhoto.id)
        let liveItem = try #require(vm.currentPage?.allItems.first { $0.photoID == livePhoto.id })
        vm.toggleMotion(liveItem.id)
        try await Task.sleep(for: .milliseconds(50))
        let motionBroadcast = realtime.broadcastedEvents.last { $0.type == .itemTransformed }
        #expect(motionBroadcast?.itemID == liveItem.id)
        #expect(motionBroadcast?.loopEnabled == false)
        realtime.simulateIncomingEvent(ScrapbookEvent(
            type: .itemTransformed, pageIndex: 0, senderID: "peer",
            itemID: liveItem.id, loopEnabled: true
        ))
        #expect(liveItem.loopEnabled == true)

        // Cut + undo (change 025): friends get the piece removed and the whole photo back
        liveItem.centerX = 0.5
        liveItem.centerY = 0.5
        liveItem.rotation = 0
        let pageSize = CGSize(width: 300, height: 400)
        #expect(vm.cut(along: [CGPoint(x: 0, y: 200), CGPoint(x: 150, y: 201), CGPoint(x: 300, y: 200)], pageSize: pageSize))
        let pieceID = try #require(vm.currentPage?.allItems.first { $0.photoID == livePhoto.id && $0.id != liveItem.id }?.id)
        realtime.broadcastedEvents.removeAll()
        vm.undo()
        try await Task.sleep(for: .milliseconds(50))
        #expect(realtime.broadcastedEvents.contains { $0.type == .itemRemoved && $0.itemID == pieceID })
        let maskRestore = try #require(realtime.broadcastedEvents.last { $0.type == .itemCut })
        #expect(maskRestore.itemID == liveItem.id)
        #expect(maskRestore.maskData == nil)

        // Simulate peer state where pieces exist and original is absent, then apply itemCutUndone
        let restoredID = UUID()
        let pieceA = ScrapbookItemPayload(id: UUID(), photoID: stillPhoto.id, centerX: 0.4, centerY: 0.4, width: 0.4, rotation: 0, zIndex: 5)
        let pieceB = ScrapbookItemPayload(id: UUID(), photoID: stillPhoto.id, centerX: 0.6, centerY: 0.6, width: 0.4, rotation: 0, zIndex: 6)
        realtime.simulateIncomingEvent(ScrapbookEvent(type: .itemPlaced, pageIndex: 0, senderID: "peer", item: pieceA))
        realtime.simulateIncomingEvent(ScrapbookEvent(type: .itemPlaced, pageIndex: 0, senderID: "peer", item: pieceB))
        let original = ScrapbookItemPayload(id: restoredID, photoID: stillPhoto.id, centerX: 0.5, centerY: 0.5, width: 0.45, rotation: 0, zIndex: 5)
        realtime.simulateIncomingEvent(ScrapbookEvent(
            type: .itemCutUndone, pageIndex: 0, senderID: "peer",
            restoredItem: original, removedPieceIDs: [pieceA.id, pieceB.id]
        ))
        #expect(vm.currentPage?.allItems.contains { $0.id == restoredID } == true)
        #expect(vm.currentPage?.allItems.contains { $0.id == pieceA.id || $0.id == pieceB.id } == false)
    }

    @Test func dragToTrashRemovesCutPiecesStickersAndCancelsSafely() async throws {
        let realtime = MockScrapbookRealtimeService()
        let vm = ScrapbookViewModel(modelContext: context, sessionStore: SessionStore(modelContext: context),
                                    scrapbookID: scrapbook.id, realtimeService: realtime)
        await vm.connectRealtime()
        vm.pageGlobalFrames[try #require(vm.currentPage).id] = CGRect(x: 20, y: 100, width: 300, height: 400)
        vm.trashDropFrame = CGRect(x: 150, y: 600, width: 64, height: 64)

        // Cut a photo into two pieces
        vm.addPhoto(stillPhoto.id, at: CGPoint(x: 0.5, y: 0.5))
        let photoItem = try #require(vm.currentPage?.allItems.first)
        photoItem.rotation = 0
        #expect(vm.cut(along: [CGPoint(x: 0, y: 200), CGPoint(x: 150, y: 201), CGPoint(x: 300, y: 200)],
                       pageSize: CGSize(width: 300, height: 400)))
        let pieces = vm.currentPage?.allItems.filter { $0.photoID == stillPhoto.id } ?? []
        #expect(pieces.count == 2)

        // Dragging outside trash keeps piece
        vm.updateItemDrag(itemID: pieces[0].id, pageLocation: CGPoint(x: 100, y: 200))
        #expect(vm.draggedItemID == pieces[0].id)
        #expect(!vm.isTrashTargeted)
        #expect(!vm.endItemDrag(itemID: pieces[0].id))
        #expect(vm.draggedItemID == nil)
        #expect(vm.currentPage?.allItems.count == 2)

        // Dragging into trash zone deletes leftover piece immediately and broadcasts removal
        // Global target center is (182, 632) -> page location (162, 532)
        vm.updateItemDrag(itemID: pieces[0].id, pageLocation: CGPoint(x: 162, y: 532))
        #expect(vm.isTrashTargeted)
        #expect(vm.endItemDrag(itemID: pieces[0].id))
        #expect(vm.trashedItemCount == 1)
        #expect(vm.currentPage?.allItems.map(\.id) == [pieces[1].id])
        #expect(!vm.trayPhotos.contains { $0.id == stillPhoto.id })

        // Trashing the last piece returns photo to PhotoTray
        vm.updateItemDrag(itemID: pieces[1].id, pageLocation: CGPoint(x: 162, y: 532))
        #expect(vm.endItemDrag(itemID: pieces[1].id))
        #expect(vm.trashedItemCount == 2)
        #expect(vm.currentPage?.allItems.isEmpty == true)
        #expect(vm.trayPhotos.map(\.id) == [livePhoto.id, stillPhoto.id])

        // Stickers return to their sticker sheet slot on trash/remove and can be placed again
        let sticker = try #require(StickerCatalog.travel.stickers.first)
        #expect(vm.placeSticker(sticker, center: CGPoint(x: 150, y: 200), width: 60, rotation: 0,
                                pageFrame: CGRect(x: 0, y: 0, width: 300, height: 400)))
        #expect(vm.existingSheet(for: StickerCatalog.travel)?.usedStickerIDs.contains(sticker.id) == true)
        let stickerItem = try #require(vm.currentPage?.allItems.first)
        vm.updateItemDrag(itemID: stickerItem.id, pageLocation: CGPoint(x: 162, y: 532))
        #expect(vm.endItemDrag(itemID: stickerItem.id))
        #expect(vm.currentPage?.allItems.isEmpty == true)
        #expect(vm.existingSheet(for: StickerCatalog.travel)?.usedStickerIDs.contains(sticker.id) == false)
        #expect(vm.placeSticker(sticker, center: CGPoint(x: 150, y: 200), width: 60, rotation: 0,
                                pageFrame: CGRect(x: 0, y: 0, width: 300, height: 400)))
        let rePlacedSticker = try #require(vm.currentPage?.allItems.first)
        realtime.simulateIncomingEvent(ScrapbookEvent(
            type: .itemRemoved, pageIndex: 0, senderID: "peer", itemID: rePlacedSticker.id
        ))
        #expect(vm.existingSheet(for: StickerCatalog.travel)?.usedStickerIDs.contains(sticker.id) == false)

        try await Task.sleep(for: .milliseconds(50))
        let removedIDs = Set(realtime.broadcastedEvents.filter { $0.type == .itemRemoved }.compactMap(\.itemID))
        #expect(removedIDs.isSuperset(of: [pieces[0].id, pieces[1].id, stickerItem.id]))

        // Remote deletion while dragging clears active drag state safely
        let letter = try #require(LetterCatalog.letters.first)
        #expect(vm.addLetter(letter))
        let letterItem = try #require(vm.currentPage?.allItems.first)
        vm.updateItemDrag(itemID: letterItem.id, pageLocation: CGPoint(x: 162, y: 532))
        #expect(vm.draggedItemID == letterItem.id)
        realtime.simulateIncomingEvent(ScrapbookEvent(
            type: .itemRemoved, pageIndex: 0, senderID: "peer", itemID: letterItem.id
        ))
        #expect(vm.draggedItemID == nil)
        #expect(!vm.isTrashTargeted)
    }

    // MARK: - Pencil

    @Test func drawingGoesIntoTheFrontLayerOrANewOne() throws {
        let vm = makeEditor()
        vm.selectTrayTool(.pencil)
        let firstLayer = try #require(vm.activeDrawingID)
        vm.updateActiveDrawing(Data("first".utf8))
        vm.selectTrayTool(.pencil)
        #expect(vm.activeDrawingID == nil)

        // The frontmost item is still the drawing: strokes continue in it.
        vm.selectTrayTool(.pencil)
        #expect(vm.activeDrawingID == firstLayer)
        vm.selectTrayTool(.pencil)

        // A photo on top: a new layer in front of it, the old drawing stays under the photo.
        vm.addPhoto(stillPhoto.id)
        vm.selectTrayTool(.pencil)
        let secondLayer = try #require(vm.activeDrawingID)
        #expect(secondLayer != firstLayer)
        vm.updateActiveDrawing(Data("second".utf8))
        vm.closeTray()

        let order = try #require(vm.currentPage?.sortedItems.map(\.kind))
        #expect(order == [.drawing, .photo, .drawing])
        #expect(vm.currentPage?.sortedItems.last?.drawingData == Data("second".utf8))
    }

    @Test func anEmptyLayerIsRemovedWhenPencilCloses() {
        let vm = makeEditor()
        vm.selectTrayTool(.pencil)
        #expect(vm.currentPage?.allItems.count == 1)
        vm.updateActiveDrawing(Data("stroke".utf8))
        vm.updateActiveDrawing(nil)
        vm.selectTrayTool(.photo)
        #expect(vm.activeDrawingID == nil)
        #expect(vm.currentPage?.allItems.isEmpty == true)
    }

    @Test func anOldPageDrawingBecomesABackLayer() throws {
        let page = ScrapbookPage(order: 0)
        context.insert(page)
        page.scrapbook = scrapbook
        let photo = ScrapbookItem(photoID: stillPhoto.id, centerX: 0.5, centerY: 0.5, width: 0.45, rotation: 0, zIndex: 3)
        context.insert(photo)
        photo.page = page
        page.drawingData = Data("old drawing".utf8)
        try context.save()

        let vm = makeEditor()

        #expect(page.drawingData == nil)
        let items = page.sortedItems
        #expect(items.map(\.kind) == [.drawing, .photo])
        #expect(items.first?.drawingData == Data("old drawing".utf8))
        _ = vm
        _ = makeEditor()
        #expect(page.allItems.count == 2)
    }

    // MARK: - Book view and spread editor (change 025)

    @Test func pageHintShowsOncePerUser() {
        let defaults = freshDefaults()
        let first = ScrapbookViewModel(modelContext: context, sessionStore: SessionStore(modelContext: context),
                                       scrapbookID: scrapbook.id, defaults: defaults)
        #expect(first.showsPageHint)
        first.dismissPageHint()
        #expect(!first.showsPageHint)

        let other = Scrapbook(title: "Other")
        context.insert(other)
        let second = ScrapbookViewModel(modelContext: context, sessionStore: SessionStore(modelContext: context),
                                        scrapbookID: other.id, defaults: defaults)
        #expect(!second.showsPageHint)
    }

    @Test func backLeavesOnlyAfterYes() {
        let vm = makeEditor()
        navigator.path = [.scrapbook(scrapbook.id)]
        vm.requestBack()
        #expect(vm.isBackConfirmationPresented)
        vm.isBackConfirmationPresented = false
        #expect(navigator.path == [.scrapbook(scrapbook.id)])

        vm.requestBack()
        vm.confirmBack()
        #expect(navigator.path.isEmpty)
    }

    @Test func zoomCyclesSpreadLeftRightAndPicksTheActivePage() throws {
        let vm = makeEditor()
        vm.openSpread()
        #expect(vm.mode == .edit)
        #expect(vm.zoom == .spread)
        #expect(vm.allowsLandscape)
        #expect(vm.editablePages.count == 2)

        vm.cycleZoom()
        #expect(vm.zoom == .left)
        #expect(vm.currentPage?.id == vm.leftPage?.id)
        #expect(!vm.allowsLandscape)
        #expect(vm.editablePages.map(\.id) == [try #require(vm.leftPage).id])

        vm.cycleZoom()
        #expect(vm.zoom == .right)
        #expect(vm.currentPage?.id == vm.rightPage?.id)
        #expect(vm.addPhoto(stillPhoto.id))
        #expect(vm.rightPage?.allItems.count == 1)

        vm.cycleZoom()
        #expect(vm.zoom == .spread)
        vm.closeSpread()
        #expect(vm.mode == .book)
        #expect(!vm.allowsLandscape)
    }

    @Test func itemsCrossTheGutterOnlyOnTheSpread() throws {
        let vm = makeEditor()
        vm.openSpread()
        let left = try #require(vm.leftPage)
        let right = try #require(vm.rightPage)
        vm.addPhoto(stillPhoto.id, at: CGPoint(x: 0.8, y: 0.5))
        let item = try #require(left.allItems.first)
        let pageSize = CGSize(width: 200, height: 266)

        // Dragged 0.4 page widths to the right: centre at 1.2 → right page at 0.2.
        vm.commitTransform(itemID: item.id, translation: CGSize(width: 80, height: 0), scale: 1, rotationDelta: 0,
                           pageSize: pageSize)
        #expect(item.page?.id == right.id)
        #expect(abs(item.centerX - 0.2) < 0.0001)
        #expect(vm.currentPage?.id == right.id)

        vm.undo()
        #expect(item.page?.id == left.id)
        #expect(abs(item.centerX - 0.8) < 0.0001)

        // Zoomed to the left page: the item stays on it.
        vm.cycleZoom()
        vm.commitTransform(itemID: item.id, translation: CGSize(width: 80, height: 0), scale: 1, rotationDelta: 0,
                           pageSize: pageSize)
        #expect(item.page?.id == left.id)
        #expect(item.centerX == 1)
    }

    @Test func undoAndRedoCoverEveryChange() throws {
        let vm = makeEditor()
        vm.openSpread()
        #expect(!vm.canUndo)
        #expect(!vm.canRedo)

        vm.addPhoto(stillPhoto.id, at: CGPoint(x: 0.5, y: 0.5))
        let photo = try #require(vm.currentPage?.allItems.first)
        vm.commitTransform(itemID: photo.id, translation: CGSize(width: 30, height: 0), scale: 1, rotationDelta: 0,
                           pageSize: CGSize(width: 300, height: 400))
        #expect(abs(photo.centerX - 0.6) < 0.0001)

        vm.selectTrayTool(.text)
        vm.textEditor?.draft = "Bali"
        vm.commitTextEditor()
        #expect(vm.currentPage?.allItems.count == 2)

        vm.undo()
        #expect(vm.currentPage?.allItems.count == 1)
        vm.undo()
        #expect(abs(photo.centerX - 0.5) < 0.0001)
        #expect(vm.canRedo)

        vm.redo()
        #expect(abs(photo.centerX - 0.6) < 0.0001)

        // A new change clears the redo steps.
        vm.removeItem(photo.id)
        #expect(!vm.canRedo)
        #expect(vm.currentPage?.allItems.isEmpty == true)
        vm.undo()
        #expect(vm.currentPage?.allItems.contains { $0.photoID == stillPhoto.id } == true)

        // Pencil strokes are undone one by one.
        vm.selectTrayTool(.pencil)
        vm.updateActiveDrawing(Data("stroke 1".utf8))
        vm.updateActiveDrawing(Data("stroke 2".utf8))
        vm.undo()
        #expect(vm.activeDrawingData == Data("stroke 1".utf8))
        vm.redo()
        #expect(vm.activeDrawingData == Data("stroke 2".utf8))

        // Closing the editor starts a new history.
        vm.closeSpread()
        vm.openSpread()
        #expect(!vm.canUndo)
        #expect(!vm.canRedo)
    }

    @Test func pencilDrawsOnBothPagesOfTheSpread() throws {
        let vm = makeEditor()
        vm.openSpread()
        let left = try #require(vm.leftPage)
        let right = try #require(vm.rightPage)
        vm.selectTrayTool(.pencil)
        #expect(vm.drawingLayerIDs.keys.sorted { $0.uuidString < $1.uuidString }
                == [left.id, right.id].sorted { $0.uuidString < $1.uuidString })

        vm.updateDrawing(Data("right".utf8), onPage: right.id)
        #expect(vm.drawingData(onPage: right.id) == Data("right".utf8))
        #expect(vm.currentPage?.id == right.id)

        // Closing Pencil keeps the right page's strokes and drops the empty left layer.
        vm.selectTrayTool(.pencil)
        #expect(left.allItems.isEmpty)
        #expect(right.allItems.map(\.kind) == [.drawing])

        // Zoomed to one page, only that page gets a canvas.
        vm.cycleZoom()
        vm.selectTrayTool(.pencil)
        #expect(Array(vm.drawingLayerIDs.keys) == [left.id])
    }

    @Test func trayDropsLandOnTheHalfOfTheSpreadUnderTheFinger() throws {
        let vm = makeEditor()
        vm.openSpread()
        #expect(vm.dropFromTray(.photo(livePhoto.id), at: CGPoint(x: 0.75, y: 0.5)))
        let placed = try #require(vm.rightPage?.allItems.first)
        #expect(abs(placed.centerX - 0.5) < 0.0001)
        #expect(vm.currentPage?.id == vm.rightPage?.id)
    }

    @Test func whosHereSplitsThisSpreadAndOtherPages() async {
        let realtime = MockScrapbookRealtimeService()
        let vm = ScrapbookViewModel(modelContext: context, sessionStore: SessionStore(modelContext: context),
                                    scrapbookID: scrapbook.id, currentUser: UserProfile(appleUserID: "me", name: "Nabiel"),
                                    realtimeService: realtime)
        await vm.connectRealtime()
        realtime.simulateIncomingPresence([
            CollaboratorPresence(id: "a", name: "Lepin", colorHex: "#27AE60", currentPageIndex: 1),
            CollaboratorPresence(id: "b", name: "Sanny", colorHex: "#E50935", currentPageIndex: 4),
        ])
        #expect(vm.whosHereOnThisSpread.map(\.name) == ["Nabiel", "Lepin"])
        #expect(vm.whosHereOnThisSpread.first?.isMe == true)
        #expect(vm.whosHereOnOtherPages.map(\.name) == ["Sanny"])
        #expect(vm.whosHereOnOtherPages.first?.pageNumber == 5)
    }

    // MARK: - Profile

    private func makeProfile(_ list: DeletedScrapbookList) -> ProfileViewModel {
        ProfileViewModel(
            modelContext: context,
            currentUser: UserProfile(appleUserID: "host-1", name: "Nabiel"),
            navigator: navigator,
            deletedScrapbooks: list
        )
    }

    @Test func profileListsScrapbooksNewestFirstAndOpensTheEditor() {
        let older = Scrapbook(title: "Old", createdDate: Date(timeIntervalSince1970: 0))
        context.insert(older)
        let profile = makeProfile(DeletedScrapbookList(defaults: UserDefaults(suiteName: UUID().uuidString)!))

        profile.reload()
        #expect(profile.scrapbooks.map(\.title) == ["Bali '27", "Old"])
        #expect(profile.pageCountText(for: older) == "1 page")

        profile.open(scrapbook)
        #expect(navigator.path == [.scrapbook(scrapbook.id)])
    }

    @Test func deletingAScrapbookRemovesItsLocalDataAndIsRemembered() throws {
        let session = CaptureSession(id: sessionID, name: "Bali '27", hostUserID: "host-1",
                                     participantIDs: [], participantNames: [], status: .ended)
        context.insert(session)
        _ = makeEditor()
        let list = DeletedScrapbookList(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let profile = makeProfile(list)
        profile.reload()

        profile.requestDelete(scrapbook)
        profile.confirmDelete()

        #expect(profile.scrapbooks.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Scrapbook>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ScrapPhoto>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CaptureSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ScrapbookPage>()).isEmpty)
        #expect(list.contains(sessionID))
    }
}

// MARK: - Cover and finishing (change 026)

private final class CoverRoomService: RollRoomServicing {
    var lastErrorDescription: String?
    var doneUserIDs: [String] = []
    var locked = false
    var participants: [RoomParticipant] = []
    private(set) var markedDone: [String] = []
    private(set) var lockCount = 0

    func createRoom(_ draft: RoomDraft) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func joinRoom(code: String, as user: RoomParticipant) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func acceptShare(_ metadata: CKShare.Metadata, as user: RoomParticipant) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func fetchRoom(code: String, zoneOwnerName: String?) async throws -> RoomSnapshot {
        RoomSnapshot(sessionID: UUID(), rollCode: code, name: "Bali '27", hostUserID: "host-1", rollSize: 24, slotsUsed: 2,
                     filterRaw: RollFilter.colorPrint200.rawValue, statusRaw: SessionStatus.ended.rawValue,
                     participants: participants, shareURL: nil, zoneOwnerName: zoneOwnerName,
                     doneEditingUserIDs: doneUserIDs, scrapbookLocked: locked)
    }
    func removeParticipant(userID: String, fromRoom code: String) async throws {}
    func leaveRoom(code: String, zoneOwnerName: String, userID: String) async throws {}
    func deleteRoom(code: String) async throws {}
    func listRooms() async throws -> [RoomSnapshot] { [] }
    func downloadShotPayload(recordName: String) async throws -> Data { throw RoomError.notFound }
    func markDoneEditing(userID: String, inRoom code: String, zoneOwnerName: String?) async throws { markedDone.append(userID) }
    func lockScrapbook(inRoom code: String, zoneOwnerName: String?) async throws { lockCount += 1 }
}

private final class CoverNavigator: Navigator {
    var selectedTab: AppTab = .home
    var path: [AppRoute] = []
    var isTabBarHidden = false
    var cameraReturnPhase: CameraReturnPhase = .idle
    var cameraReturnAngle: Double = 0.0
}

@MainActor
struct ScrapbookCoverTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let sessionID = UUID()
    let scrapbook: Scrapbook
    let host = UserProfile(appleUserID: "host-1", name: "Nabiel")
    let guest = UserProfile(appleUserID: "guest-2", name: "Brian")
    private let navigator = CoverNavigator()
    private let room = CoverRoomService()
    private let realtime = MockScrapbookRealtimeService()

    init() throws {
        container = try ModelContainer(
            for: ScrapIt.schema,
            configurations: ModelConfiguration(UUID().uuidString, schema: ScrapIt.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        scrapbook = Scrapbook(title: "Bali '27", memberIDs: ["host-1", "guest-2"], memberNames: ["Nabiel", "Brian"],
                              sourceSessionID: sessionID)
        let session = CaptureSession(id: sessionID, name: "Bali '27", rollCode: "N4B13L", hostUserID: "host-1",
                                     participantIDs: ["host-1", "guest-2"], participantNames: ["Nabiel", "Brian"],
                                     status: .ended)
        context.insert(scrapbook)
        context.insert(session)
        try context.save()
    }

    private func makeEditor(as user: UserProfile) -> ScrapbookViewModel {
        ScrapbookViewModel(modelContext: context, navigator: navigator, sessionStore: SessionStore(modelContext: context),
                           scrapbookID: scrapbook.id, currentUser: user, realtimeService: realtime,
                           defaults: UserDefaults(suiteName: UUID().uuidString)!, roomService: room)
    }

    @Test func hostAndParticipantGetTheirOwnButtons() {
        let hostVM = makeEditor(as: host)
        #expect(hostVM.isHost)
        #expect(hostVM.coverActions == .host)
        let guestVM = makeEditor(as: guest)
        #expect(!guestVM.isHost)
        #expect(guestVM.coverActions == .participant)
    }

    @Test func doneIsFinalForThePagesAndTheHostCountsAsDone() async throws {
        let vm = makeEditor(as: host)
        vm.finishScrapbook()
        #expect(vm.mode == .cover)
        #expect(!vm.isBookEditable)
        #expect(vm.editingDone.map(\.id) == ["host-1"])
        try await Task.sleep(for: .milliseconds(50))
        #expect(room.markedDone == ["host-1"])
        #expect(realtime.broadcastedEvents.contains { $0.type == .editingDone && $0.memberID == "host-1" })

        // The pages can't be edited again, and reading never adds pages.
        vm.openReadOnlyBook()
        #expect(vm.mode == .book)
        vm.openSpread()
        #expect(vm.mode == .book)
        let pageCount = vm.pages.count
        vm.swipeSpread(by: 1)
        #expect(vm.pages.count == pageCount)
        vm.closeReadOnlyBook()
        #expect(vm.mode == .cover)

        // Opening it again starts on the closed book.
        #expect(makeEditor(as: host).mode == .cover)
    }

    @Test func participantDoneEditingIsReadOnly() {
        let vm = makeEditor(as: guest)
        vm.finishScrapbook()
        #expect(vm.editingDone.isEmpty)
        vm.doneEditing()
        #expect(vm.finishCard == .niceWork)
        #expect(vm.isReadOnly)
        #expect(vm.coverActions == .finished)
        vm.dismissFinishCard()
        vm.editCover()
        #expect(vm.mode == .cover)
        vm.backToHome()
        #expect(navigator.selectedTab == .home)
    }

    @Test func saveAsksFirstOnlyWhileSomeoneIsInProgress() async throws {
        let vm = makeEditor(as: host)
        vm.finishScrapbook()
        #expect(vm.editingInProgress.map(\.id) == ["guest-2"])
        vm.requestSave()
        #expect(vm.finishCard == .confirmSave)
        vm.dismissFinishCard()
        #expect(!vm.isLocked)

        vm.requestSave()
        vm.saveScrapbook()
        #expect(vm.isLocked)
        #expect(vm.finishCard == .complete)
        try await Task.sleep(for: .milliseconds(50))
        #expect(room.lockCount == 1)
        #expect(realtime.broadcastedEvents.contains { $0.type == .scrapbookLocked })
        vm.viewBookshelf()
        #expect(navigator.selectedTab == .profile)
        #expect(navigator.path.isEmpty)
    }

    @Test func saveGoesStraightThroughWhenEveryoneIsDone() {
        scrapbook.doneEditingMemberIDs = ["guest-2"]
        let vm = makeEditor(as: host)
        vm.finishScrapbook()
        vm.requestSave()
        #expect(vm.isLocked)
        #expect(vm.finishCard == .complete)
    }

    @Test func aFriendLockingTurnsTheEditorReadOnly() async {
        let vm = makeEditor(as: guest)
        await vm.connectRealtime()
        vm.openSpread()
        #expect(vm.mode == .edit)
        realtime.simulateIncomingEvent(ScrapbookEvent(type: .scrapbookLocked, pageIndex: 0, senderID: "host-1"))
        #expect(vm.isLocked)
        #expect(vm.isReadOnly)
        #expect(vm.mode == .cover)
        #expect(vm.coverActions == .finished)
    }

    @Test func unpickedCoverShowsTheDefaultBlueAndAPickedWhiteStays() async throws {
        scrapbook.coverColorHex = "#FFFFFF"
        let vm = makeEditor(as: guest)
        await vm.connectRealtime()
        #expect(vm.coverColorHex == Scrapbook.defaultCoverColorHex)
        #expect(scrapbook.displayedCoverColorHex == Scrapbook.defaultCoverColorHex)

        vm.setCoverColor("#FFFFFF")
        #expect(scrapbook.coverColorPicked)
        #expect(vm.coverColorHex == "#FFFFFF")
        #expect(scrapbook.displayedCoverColorHex == "#FFFFFF")
    }

    @Test func aFriendsPickedColorCounts() async throws {
        scrapbook.coverColorHex = "#FFFFFF"
        let vm = makeEditor(as: guest)
        await vm.connectRealtime()
        realtime.simulateIncomingEvent(ScrapbookEvent(type: .coverColor, pageIndex: -1, senderID: "host-1", coverColor: "#FFFFFF"))
        #expect(scrapbook.coverColorPicked)
        #expect(vm.coverColorHex == "#FFFFFF")
    }

    @Test func pencilStrokesOnTheCoverAreKept() async throws {
        let vm = makeEditor(as: host)
        vm.finishScrapbook()
        vm.editCover()
        for side in [CoverSide.front, .spine] {
            if side == .spine { vm.showSpine() }
            #expect(vm.beginDrawing())
            let page = try #require(vm.coverPage(side.role))
            vm.updateDrawing(Data("strokes".utf8), onPage: page.id)
            vm.endDrawing()
            #expect(page.allItems.contains { $0.kind == .drawing && $0.drawingData == Data("strokes".utf8) })
        }
    }

    @Test func aStickerOnTheSpineCanStillGrow() throws {
        let vm = makeEditor(as: host)
        vm.finishScrapbook()
        vm.editCover()
        vm.showSpine()
        vm.toggleStickerSheet(StickerCatalog.travel)
        let sticker = try #require(vm.stickerSet.stickers.first)
        let frame = CGRect(x: 0, y: 0, width: 74, height: 462)
        #expect(vm.placeSticker(sticker, center: CGPoint(x: 37, y: 200), width: 90, rotation: 0, pageFrame: frame))
        let item = try #require(vm.coverPage(.spine)?.allItems.first { $0.kind == .sticker })
        #expect(item.width < item.widthRange.upperBound)
    }

    @Test func closingTheSecondTrayKeepsTheCoverTrayOpen() {
        let vm = makeEditor(as: host)
        vm.finishScrapbook()
        vm.editCover()
        vm.selectTrayTool(.pencil)
        #expect(vm.isDrawing)
        vm.closeSubTray()
        #expect(vm.activeTool == nil)
        #expect(!vm.isDrawing)
        #expect(vm.isTrayOpen)
    }

    @Test func closingTheTrayPutsTheWashiAway() throws {
        let style = try #require(WashiCatalog.styles.first)
        let vm = makeEditor(as: host)
        vm.openSpread()
        vm.openTray()
        vm.selectTrayTool(.washi)
        vm.selectWashi(style)
        #expect(vm.washiStyleID == style.id)
        vm.closeTray()
        #expect(vm.washiStyleID == nil)

        vm.openTray()
        vm.selectTrayTool(.washi)
        vm.selectWashi(style)
        vm.closeSubTray()
        #expect(vm.washiStyleID == nil)

        // The tap of the swipe that closed the tray arrives late: no washi.
        vm.selectWashi(style)
        #expect(vm.washiStyleID == nil)
    }

    @Test func coverColorIsSavedAndShared() async throws {
        let vm = makeEditor(as: guest)
        await vm.connectRealtime()
        #expect(vm.coverColorHex == "#303D6E")
        vm.setCoverColor("#2B3A78")
        #expect(scrapbook.coverColorHex == "#2B3A78")
        try await Task.sleep(for: .milliseconds(50))
        #expect(realtime.broadcastedEvents.contains { $0.type == .coverColor && $0.coverColor == "#2B3A78" })

        realtime.simulateIncomingEvent(ScrapbookEvent(type: .coverColor, pageIndex: -1, senderID: "host-1", coverColor: "#6B2430"))
        #expect(vm.coverColorHex == "#6B2430")
    }

    @Test func coverSidesHaveTheirOwnItemsAndTools() async throws {
        let vm = makeEditor(as: host)
        await vm.connectRealtime()
        vm.finishScrapbook()
        vm.editCover()
        #expect(vm.mode == .editCover)
        #expect(vm.isTrayOpen)
        #expect(vm.availableTools == [.pencil, .sticker, .washi, .letters, .text])
        let front = try #require(vm.coverPage(.front))
        #expect(!vm.pages.contains { $0.id == front.id })

        #expect(vm.addLetter(try #require(LetterCatalog.letters.first)))
        #expect(front.allItems.count == 1)
        try await Task.sleep(for: .milliseconds(50))
        #expect(realtime.broadcastedEvents.contains { $0.type == .itemPlaced && $0.pageIndex == -1 })

        vm.showSpine()
        #expect(vm.availableTools == [.pencil, .sticker, .text])
        vm.selectTrayTool(.text)
        vm.textEditor?.draft = "Bali with the gang!"
        vm.commitTextEditor()
        let spine = try #require(vm.coverPage(.spine))
        let spineText = try #require(spine.allItems.first)
        #expect(abs(spineText.rotation + .pi / 2) < 0.0001)
        #expect(spineText.width == ScrapbookViewModel.spineTextSize)

        vm.finishCoverEdit()
        #expect(vm.mode == .cover)
        #expect(!vm.isTrayOpen)
    }

    @Test func friendsCoverItemsAndStatusesArrive() async {
        let vm = makeEditor(as: host)
        await vm.connectRealtime()
        realtime.simulateIncomingEvent(ScrapbookEvent(
            type: .itemPlaced, pageIndex: -2, senderID: "guest-2",
            item: ScrapbookItemPayload(id: UUID(), centerX: 0.5, centerY: 0.5, width: 0.27, rotation: 0, zIndex: 1, text: "Hi")
        ))
        #expect(vm.coverPage(.spine)?.allItems.count == 1)

        realtime.simulateIncomingEvent(ScrapbookEvent(type: .editingDone, pageIndex: 0, senderID: "guest-2", memberID: "guest-2"))
        #expect(vm.editingDone.map(\.id) == ["guest-2"])
    }

    @Test func editingProgressShowsProfilePhotos() async {
        let myPhoto = Data("my photo".utf8)
        let friendPhoto = Data("friend photo".utf8)
        host.avatarData = myPhoto
        room.participants = [RoomParticipant(userID: "guest-2", name: "Brian", avatarData: friendPhoto)]
        let vm = makeEditor(as: host)
        await vm.refreshFinishStatus()
        let rows = vm.editingInProgress + vm.editingDone
        #expect(rows.first { $0.isMe }?.avatarData == myPhoto)
        #expect(rows.first { $0.id == "guest-2" }?.avatarData == friendPhoto)
    }

    @Test func statusesAreReadFromTheRoom() async {
        room.doneUserIDs = ["guest-2"]
        room.locked = true
        let vm = makeEditor(as: host)
        await vm.refreshFinishStatus()
        #expect(vm.editingDone.map(\.id).contains("guest-2"))
        #expect(vm.isLocked)
        #expect(vm.mode == .cover)
    }
}
