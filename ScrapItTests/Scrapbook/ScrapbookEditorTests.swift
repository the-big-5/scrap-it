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

    @Test func pickerOffersOnlyThisRollsPhotos() {
        let other = ScrapPhoto(imageData: Data(), authorID: "x", authorName: "X", sourceSessionID: UUID())
        context.insert(other)
        let vm = makeEditor()

        #expect(vm.rollPhotos.map(\.id) == [stillPhoto.id, livePhoto.id])
        vm.addPhotos([stillPhoto.id, other.id, livePhoto.id])

        #expect(vm.currentPage?.allItems.compactMap(\.photoID).sorted { $0.uuidString < $1.uuidString }
                == [stillPhoto.id, livePhoto.id].sorted { $0.uuidString < $1.uuidString })
        let live = vm.currentPage?.allItems.first { $0.photoID == livePhoto.id }
        #expect(live.map(vm.isLive) == true)
    }

    @Test func aPageHoldsAtMostTwentyItems() {
        let vm = makeEditor()
        for _ in 0..<12 {
            vm.addPhotos([stillPhoto.id, livePhoto.id])
        }
        #expect(vm.currentPage?.allItems.count == ScrapbookPage.maxItems)
        #expect(vm.remainingSlots == 0)

        vm.presentPhotoPicker()
        #expect(!vm.isPhotoPickerPresented)
        #expect(vm.toastMessage == ScrapbookViewModel.pageFullMessage)
    }

    @Test func reduceMotionAddsLivePhotosWithMotionOff() throws {
        let vm = makeEditor()
        vm.addPhotos([livePhoto.id], reduceMotion: true)
        let item = try #require(vm.currentPage?.allItems.first)
        #expect(!item.loopEnabled)
        vm.toggleMotion(item.id)
        #expect(item.loopEnabled)
    }

    // MARK: - Arranging

    @Test func transformIsClampedAndRotationSnaps() throws {
        let vm = makeEditor()
        vm.addPhotos([stillPhoto.id])
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
        vm.addPhotos([stillPhoto.id, livePhoto.id])
        let back = try #require(vm.currentPage?.sortedItems.first)

        vm.selectItem(back.id)

        #expect(vm.selectedItemID == back.id)
        #expect(vm.currentPage?.sortedItems.last?.id == back.id)
    }

    // MARK: - Scissors

    @Test func cuttingSplitsAPhotoAndUndoRestoresIt() throws {
        let vm = makeEditor()
        vm.addPhotos([stillPhoto.id])
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
        vm.addPhotos([stillPhoto.id])
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
        vm.selectTool(.stickers)
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

    // MARK: - Pencil

    @Test func drawingIsSavedPerPage() throws {
        let vm = makeEditor()
        let first = try #require(vm.currentPage)
        vm.addPage()
        let drawing = Data("strokes".utf8)

        vm.updateDrawing(drawing, pageID: first.id)

        #expect(first.drawingData == drawing)
        #expect(vm.currentPage?.drawingData == nil)
        vm.updateDrawing(nil, pageID: first.id)
        #expect(first.drawingData == nil)
    }

    @Test func toolsSwitchAndFinish() {
        let vm = makeEditor()
        vm.selectTool(.pencil)
        #expect(vm.tool == .pencil)
        vm.finishTool()
        #expect(vm.tool == .arrange)
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
