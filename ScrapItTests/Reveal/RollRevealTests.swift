import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import ScrapIt

private final class RevealNavigator: Navigator {
    var selectedTab: AppTab = .home
    var path: [AppRoute] = []
    var isTabBarHidden = false
    var cameraReturnPhase: CameraReturnPhase = .idle
    var cameraReturnAngle: Double = 0.0
}

private final class FakePhotoSaver: PhotoLibrarySaving {
    var saved: [(Data, Data?)] = []
    var fails = false

    func save(imageData: Data, movieData: Data?) async throws {
        if fails { throw PhotoLibrarySaveError.notAuthorized }
        saved.append((imageData, movieData))
    }
}

/// Change 021: Roll Reveal after End Roll.
@MainActor
struct RollRevealTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let sessionID = UUID()
    let scrapbook: Scrapbook
    private let navigator = RevealNavigator()
    private let saver = FakePhotoSaver()
    private let screen = CGSize(width: 402, height: 874)

    init() throws {
        container = try ModelContainer(
            for: ScrapIt.schema,
            configurations: ModelConfiguration(UUID().uuidString, schema: ScrapIt.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        scrapbook = Scrapbook(title: "Bali '27", sourceSessionID: sessionID)
        context.insert(scrapbook)
        try context.save()
    }

    @discardableResult
    private func addPhoto(at time: TimeInterval, movie: Data? = nil) -> ScrapPhoto {
        let photo = ScrapPhoto(
            imageData: Data("photo-\(time)".utf8),
            livePhotoMovieData: movie,
            authorID: "host-1",
            authorName: "Nabiel",
            timestamp: Date(timeIntervalSince1970: time),
            sourceSessionID: sessionID
        )
        context.insert(photo)
        try? context.save()
        return photo
    }

    private func makeViewModel() -> RollRevealViewModel {
        RollRevealViewModel(modelContext: context, navigator: navigator, scrapbookID: scrapbook.id, photoSaver: saver)
    }

    private func addSession(shotsUsed: Int) {
        let session = CaptureSession(id: sessionID, name: "Bali '27", hostUserID: "host-1", participantIDs: [],
                                     participantNames: [], slotsUsed: shotsUsed, status: .ended)
        context.insert(session)
        try? context.save()
    }

    // MARK: - Developing envelope (change 024)

    @Test func envelopeStaysClosedUntilEveryPhotoIsIn() {
        addSession(shotsUsed: 3)
        addPhoto(at: 1)
        let viewModel = makeViewModel()
        viewModel.setMatSize(screen)
        #expect(viewModel.isDeveloping)
        #expect(!viewModel.canTear)

        viewModel.tear()
        #expect(viewModel.stage == .envelope)

        addPhoto(at: 2)
        addPhoto(at: 3)
        viewModel.refresh()
        #expect(viewModel.arrivalCount == 1)
        #expect(!viewModel.isDeveloping)
        #expect(viewModel.showsReadyText)
        #expect(viewModel.envelopeStatusText == RollRevealViewModel.readyText)
        viewModel.hideReadyText()
        #expect(!viewModel.showsReadyText)
        #expect(viewModel.envelopeStatusText == RollRevealViewModel.openHintText)
        viewModel.tear()
        #expect(viewModel.stage == .scattered)
        #expect(viewModel.envelopeStatusText == nil)
    }

    @Test func envelopeStatusTextTracksDevelopingReadyOpenHintAndTornStates() {
        addSession(shotsUsed: 2)
        addPhoto(at: 1)
        let locked = makeViewModel()
        #expect(locked.envelopeStatusText == RollRevealViewModel.printingText)

        addPhoto(at: 2)
        let ready = makeViewModel()
        ready.setMatSize(screen)
        #expect(!ready.isDeveloping)
        #expect(!ready.showsReadyText)
        #expect(ready.envelopeStatusText == RollRevealViewModel.openHintText)

        ready.tear()
        #expect(ready.stage == .scattered)
        #expect(ready.envelopeStatusText == nil)
    }

    @Test func slidingPointerGlidesLeftToRightAndFadesOutAtEndOfCycle() {
        let hiddenStart = RevealEnvelopeView.pointerFrame(at: 0.0)
        let activeStart = RevealEnvelopeView.pointerFrame(at: 0.14)
        let midpoint = RevealEnvelopeView.pointerFrame(at: 0.46)
        let activeEnd = RevealEnvelopeView.pointerFrame(at: 0.78)
        let pauseEnd = RevealEnvelopeView.pointerFrame(at: 0.95)

        #expect(hiddenStart.opacity == 0)
        #expect(activeStart.opacity == 1)
        #expect(activeEnd.opacity == 1)
        #expect(pauseEnd.opacity == 0)
        #expect(activeStart.x < midpoint.x)
        #expect(midpoint.x < activeEnd.x)
        #expect(midpoint.scale < hiddenStart.scale)
    }

    @Test func envelopeOpensAfterTenSecondsEvenWithPhotosMissing() async {
        addSession(shotsUsed: 5)
        addPhoto(at: 1)
        let waited = RollRevealViewModel(modelContext: context, navigator: navigator, scrapbookID: scrapbook.id,
                                         photoSaver: saver, openedAt: .now.addingTimeInterval(-11))
        #expect(!waited.isDeveloping)
        #expect(waited.canTear)
        #expect(!waited.showsReadyText)

        let almost = RollRevealViewModel(modelContext: context, navigator: navigator, scrapbookID: scrapbook.id,
                                         photoSaver: saver, openedAt: .now.addingTimeInterval(-9.9))
        #expect(almost.isDeveloping)
        await almost.waitForTearUnlock()
        #expect(almost.canTear)
    }

    @Test func photosArrivingAfterTheTearStillLandOnTheMat() throws {
        addSession(shotsUsed: 2)
        addPhoto(at: 1)
        let viewModel = RollRevealViewModel(modelContext: context, navigator: navigator, scrapbookID: scrapbook.id,
                                            photoSaver: saver, openedAt: .now.addingTimeInterval(-11))
        viewModel.setMatSize(screen)
        viewModel.tear()
        #expect(!viewModel.isDeveloping)

        let late = addPhoto(at: 2)
        viewModel.refresh()
        #expect(viewModel.placements[late.id] != nil)
        #expect(viewModel.gridPhotos.map(\.id).contains(late.id))
    }

    @Test func labelShowsTheRollNameAndPhotoCount() {
        addPhoto(at: 1)
        let viewModel = makeViewModel()
        #expect(viewModel.rollName == "Bali '27")
        #expect(viewModel.labelText == "1 photo")

        addPhoto(at: 2)
        viewModel.refresh()
        #expect(viewModel.labelText == "2 photos")
    }

    @Test func tearingScattersEveryPhotoInsideTheScreen() {
        for time in 0..<24 { addPhoto(at: TimeInterval(time)) }
        let viewModel = makeViewModel()
        viewModel.setMatSize(screen)
        #expect(viewModel.placements.isEmpty)

        viewModel.tear()
        #expect(viewModel.stage == .scattered)
        #expect(viewModel.placements.count == 24)
        for placement in viewModel.placements.values {
            #expect((0...screen.width).contains(placement.center.x))
            #expect((0...screen.height).contains(placement.center.y))
            #expect(abs(placement.rotation) <= RollRevealViewModel.maxRotation)
        }
    }

    @Test func scatterLayoutIsRepeatable() {
        #expect(RollRevealViewModel.scatterLayout(count: 12, in: screen) == RollRevealViewModel.scatterLayout(count: 12, in: screen))
    }

    @Test func photosArrivingAfterTheTearLandOnTheMat() {
        addPhoto(at: 1)
        let viewModel = makeViewModel()
        viewModel.setMatSize(screen)
        viewModel.tear()

        let late = addPhoto(at: 2)
        viewModel.refresh()
        #expect(viewModel.placements[late.id] != nil)
        #expect(viewModel.labelText == "2 photos")
    }

    @Test func draggingBringsAPhotoToTheFrontAndKeepsItOnTheMat() {
        let first = addPhoto(at: 1)
        let second = addPhoto(at: 2)
        let viewModel = makeViewModel()
        viewModel.setMatSize(screen)
        viewModel.tear()
        #expect(viewModel.stackIndex(of: second.id) > viewModel.stackIndex(of: first.id))

        viewModel.bringToFront(first.id)
        #expect(viewModel.stackIndex(of: first.id) > viewModel.stackIndex(of: second.id))

        viewModel.move(first.id, by: CGSize(width: -5000, height: 5000))
        let moved = try! #require(viewModel.placements[first.id]).center
        #expect((0...screen.width).contains(moved.x))
        #expect((0...screen.height).contains(moved.y))
    }

    @Test func tidyUpTogglesTheGridSortedByTime() {
        let late = addPhoto(at: 200)
        let early = addPhoto(at: 100)
        let viewModel = makeViewModel()
        viewModel.toggleTidy()
        #expect(viewModel.stage == .envelope)

        viewModel.tear()
        #expect(viewModel.tidyButtonTitle == "Tidy Up")
        viewModel.toggleTidy()
        #expect(viewModel.stage == .tidy)
        #expect(viewModel.tidyButtonTitle == "Scatter")
        #expect(viewModel.gridPhotos.map(\.id) == [early.id, late.id])

        viewModel.toggleTidy()
        #expect(viewModel.stage == .scattered)
    }

    @Test func detailSavesTheLivePhotoAndCloses() async {
        let live = addPhoto(at: 1, movie: Data("mov".utf8))
        let viewModel = makeViewModel()
        viewModel.select(live.id)
        #expect(viewModel.selectedPhoto?.id == live.id)

        await viewModel.saveSelected()
        #expect(saver.saved.count == 1)
        #expect(saver.saved.first?.1 == Data("mov".utf8))
        #expect(viewModel.saveMessage == RollRevealViewModel.savedMessage)

        viewModel.closeDetail()
        #expect(viewModel.selectedPhoto == nil)
    }

    @Test func refusedPhotosAccessShowsAShortMessage() async {
        let photo = addPhoto(at: 1)
        saver.fails = true
        let viewModel = makeViewModel()
        viewModel.select(photo.id)
        await viewModel.saveSelected()
        #expect(viewModel.saveMessage == RollRevealViewModel.saveFailedMessage)
    }

    @Test func startScrapbookOpensTheEditorWithoutTheRevealBehind() {
        navigator.path = [.rollReveal(scrapbook.id)]
        let viewModel = makeViewModel()
        viewModel.startScrapbook()
        #expect(navigator.path == [.scrapbook(scrapbook.id)])
    }
}
