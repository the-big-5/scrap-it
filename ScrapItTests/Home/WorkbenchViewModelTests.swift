import Foundation
import SwiftData
import Testing
@testable import ScrapIt

@MainActor
struct WorkbenchViewModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: UserProfile.self,
            Scrapbook.self,
            ScrapPhoto.self,
            CaptureSession.self,
            ScrapbookPage.self,
            ScrapbookItem.self,
            StickerSheet.self,
            configurations: ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "WorkbenchViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (defaults, suite)
    }

    private func makeViewModel(
        router: AppRouter? = nil,
        defaults: UserDefaults? = nil,
        delay: Duration = .milliseconds(10)
    ) -> (WorkbenchViewModel, AppRouter) {
        let resolvedRouter = router ?? AppRouter()
        let store = SessionStore(modelContext: context)
        let deleted = DeletedScrapbookList(defaults: defaults ?? makeDefaults().0)
        let vm = WorkbenchViewModel(
            modelContext: context,
            navigator: resolvedRouter,
            sessionStore: store,
            deletedScrapbooks: deleted,
            toolboxTransitionDelay: delay
        )
        return (vm, resolvedRouter)
    }

    @Test func activateToolboxHidesTabBarAndPushesCollection() async throws {
        let (vm, router) = makeViewModel(delay: .milliseconds(20))

        vm.activateToolbox()
        #expect(vm.isToolboxActive)
        #expect(router.isTabBarHidden)
        #expect(router.path.isEmpty)

        for _ in 0..<100 where vm.isToolboxActive {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isToolboxActive)
        #expect(!router.isTabBarHidden)
        #expect(router.path == [.deskCollection(.scrapbooks)])
    }

    @Test func cameraAndToolboxMutuallyExcludeAndCancelStopsNavigation() async throws {
        let (vm, router) = makeViewModel(delay: .milliseconds(80))

        vm.toggleCamera()
        #expect(vm.isCameraActive)
        vm.activateToolbox()
        #expect(!vm.isToolboxActive)

        vm.dismissCamera()
        #expect(!vm.isCameraActive)

        vm.activateToolbox()
        #expect(vm.isToolboxActive)
        vm.toggleCamera()
        #expect(!vm.isCameraActive)

        vm.cancelToolboxTransition()
        #expect(!vm.isToolboxActive)
        #expect(!router.isTabBarHidden)

        try await Task.sleep(for: .milliseconds(120))
        #expect(router.path.isEmpty)
    }

    @Test func previewPhotosAreDeterministicAndBoundedOneToFour() throws {
        let (vm, _) = makeViewModel()
        let emptyScrapbook = Scrapbook(title: "Empty")
        context.insert(emptyScrapbook)
        #expect(vm.previewPhotos(for: emptyScrapbook).isEmpty)

        let sessionID = UUID()
        let singleScrapbook = Scrapbook(title: "Single", sourceSessionID: sessionID)
        let soloPhoto = ScrapPhoto(imageData: Data([1, 2]), authorID: "u1", authorName: "A", sourceSessionID: sessionID, scrapbook: singleScrapbook)
        singleScrapbook.photos = [soloPhoto]
        context.insert(singleScrapbook)
        context.insert(soloPhoto)
        let soloPreview = vm.previewPhotos(for: singleScrapbook)
        #expect(soloPreview.count == 1)
        #expect(soloPreview.first?.id == soloPhoto.id)

        let manySessionID = UUID()
        let fullScrapbook = Scrapbook(title: "Full", sourceSessionID: manySessionID)
        var photos: [ScrapPhoto] = []
        for idx in 0..<6 {
            let photo = ScrapPhoto(
                imageData: Data([UInt8(idx)]),
                authorID: "u\(idx)",
                authorName: "User \(idx)",
                timestamp: .now.addingTimeInterval(Double(idx)),
                sourceSessionID: manySessionID,
                scrapbook: fullScrapbook
            )
            photos.append(photo)
            context.insert(photo)
        }
        fullScrapbook.photos = photos
        context.insert(fullScrapbook)
        try context.save()

        let firstRead = vm.previewPhotos(for: fullScrapbook)
        let secondRead = vm.previewPhotos(for: fullScrapbook)
        #expect((1...4).contains(firstRead.count))
        #expect(firstRead == secondRead)
    }

    @Test func folderThemesCycleBurgundyKraftNavyAndDateFormatsDDMMYYYY() {
        let (vm, _) = makeViewModel()
        #expect(vm.folderTheme(at: 0) == .burgundy)
        #expect(vm.folderTheme(at: 1) == .kraft)
        #expect(vm.folderTheme(at: 2) == .navy)
        #expect(vm.folderTheme(at: 3) == .burgundy)

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = 2026
        components.month = 11
        components.day = 2
        let date = components.date!
        let book = Scrapbook(title: "Dinner", createdDate: date)
        #expect(vm.formattedDate(for: book) == "02/11/2026")
    }

    @Test func emptyStateRoutesAndLocalDeviceRemovalCleanUpLocalStorageOnly() throws {
        let (defaults, suite) = makeDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let (vm, router) = makeViewModel(defaults: defaults)
        router.push(.deskCollection(.scrapbooks))
        vm.closeCollection()
        #expect(router.path.isEmpty)

        router.push(.deskCollection(.scrapbooks))
        vm.startCreateRollFromCollection()
        #expect(router.path == [.createRollSetup])

        let sessionID = UUID()
        let session = CaptureSession(
            id: sessionID,
            name: "Squad Day Out",
            rollCode: "ABC123",
            hostUserID: "host",
            participantIDs: ["host"],
            participantNames: ["Host"],
            rollSize: 24,
            filter: .colorPrint200,
            status: .ended
        )
        let toRemove = Scrapbook(title: "Squad Day Out", createdDate: .now, sourceSessionID: sessionID)
        let photo = ScrapPhoto(imageData: Data([9]), authorID: "host", authorName: "Host", sourceSessionID: sessionID, scrapbook: toRemove)
        toRemove.photos = [photo]
        let keep = Scrapbook(title: "Keep Me", createdDate: .now.addingTimeInterval(-60))

        context.insert(session)
        context.insert(toRemove)
        context.insert(photo)
        context.insert(keep)
        try context.save()

        vm.requestRemoveFromDevice(toRemove)
        #expect(vm.scrapbookPendingRemoval?.id == toRemove.id)

        vm.confirmRemoveFromDevice()
        #expect(vm.scrapbookPendingRemoval == nil)
        #expect(vm.scrapbooks.map(\.id) == [keep.id])
        #expect(DeletedScrapbookList(defaults: defaults).contains(sessionID))

        let remainingSessions = try context.fetch(FetchDescriptor<CaptureSession>())
        let remainingPhotos = try context.fetch(FetchDescriptor<ScrapPhoto>())
        #expect(remainingSessions.isEmpty)
        #expect(remainingPhotos.isEmpty)
    }
}
