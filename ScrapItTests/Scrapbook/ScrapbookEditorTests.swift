import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import ScrapIt

private final class EditorNavigator: Navigator {
    var selectedTab: AppTab = .home
    var path: [AppRoute] = []
    var isTabBarHidden = false
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

    @Test func newScrapbookStartsWithOneEmptyPage() {
        let vm = makeEditor()
        #expect(vm.pages.count == 1)
        #expect(vm.currentPage?.allItems.isEmpty == true)
        #expect(vm.pageIndicatorText == "1 / 1")
    }

    @Test func pagesCanBeAddedMovedAndDeleted() throws {
        let vm = makeEditor()
        let first = try #require(vm.currentPage)
        vm.addPage()
        let second = try #require(vm.currentPage)
        #expect(vm.pages.map(\.id) == [first.id, second.id])
        #expect(vm.pageIndicatorText == "2 / 2")

        vm.movePage(by: -1)
        #expect(vm.pages.map(\.id) == [second.id, first.id])

        vm.deleteCurrentPage()
        #expect(vm.pages.map(\.id) == [first.id])
        vm.deleteCurrentPage()
        #expect(vm.pages.count == 1)
    }

    @Test func backgroundIsSavedPerPage() {
        let vm = makeEditor()
        vm.setBackground(.grid)
        vm.addPage()
        #expect(vm.currentBackground == .grid)
        vm.setBackground(.kraft)
        #expect(vm.pages.map(\.pageBackground) == [.grid, .kraft])
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
        #expect(ScrapbookPage.maxItems == 40)
        for _ in 0..<ScrapbookPage.maxItems {
            vm.addPhoto(stillPhoto.id)
        }
        #expect(vm.currentPage?.allItems.count == ScrapbookPage.maxItems)
        #expect(vm.remainingSlots == 0)

        #expect(!vm.addPhoto(livePhoto.id))
        #expect(!vm.addLetter(try #require(LetterCatalog.letters.first)))
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
        #expect(vm.canUndoCut)

        vm.undoLastCut()

        #expect(vm.currentPage?.allItems.map(\.id) == [item.id])
        #expect(item.maskPolygon == nil)
        #expect(item.centerX == 0.5)
        #expect(!vm.canUndoCut)
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
        #expect(!vm.allowsPageSwipe)

        vm.selectTrayTool(.washi)
        #expect(!vm.isCutting)
        vm.tapEmptyPage()
        #expect(vm.activeTool == nil)

        vm.selectTrayTool(.sticker)
        vm.closeTray()
        #expect(!vm.isTrayOpen)
        #expect(vm.activeTool == nil)
        #expect(vm.allowsPageSwipe)
    }

    @Test func swipeChangesPageOnlyWithoutAPageTool() {
        let vm = makeEditor()
        vm.addPage()
        vm.swipePage(by: -1)
        #expect(vm.currentIndex == 0)

        vm.selectTrayTool(.scissors)
        vm.swipePage(by: 1)
        #expect(vm.currentIndex == 0)
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

    @Test func onlyPhotosAndTravelStickersAreSharedWithFriends() async throws {
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
        vm.updateActiveDrawing(Data("strokes".utf8))
        vm.selectTrayTool(.pencil)
        for item in vm.currentPage?.allItems ?? [] {
            vm.bringToFront(item.id)
        }
        try await Task.sleep(for: .milliseconds(100))

        let placed = realtime.broadcastedEvents.filter { $0.type == .itemPlaced }.compactMap(\.item)
        #expect(placed.count == 2)
        #expect(placed.contains { $0.photoID == stillPhoto.id })
        #expect(placed.contains { $0.stickerID == StickerCatalog.travel.stickers.first?.id })
        #expect(realtime.broadcastedEvents.filter { $0.type == .itemTransformed }.count == 2)
        #expect(!realtime.broadcastedEvents.contains { $0.type == .drawingUpdated })
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
