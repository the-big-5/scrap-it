import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import ScrapIt

private final class RevealNavigator: Navigator {
    var selectedTab: AppTab = .home
    var path: [AppRoute] = []
    var isTabBarHidden = false
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
