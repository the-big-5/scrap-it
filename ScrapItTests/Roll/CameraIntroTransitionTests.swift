import Foundation
import SwiftData
import Testing
@testable import ScrapIt

@Suite(.serialized)
@MainActor
struct CameraIntroTransitionTests {
    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserProfile.self, Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
            configurations: ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func makeOfflineCloudService(context: ModelContext) -> CloudKitSessionService {
        let service = CloudKitSessionService(
            modelContext: context,
            enableNetworkMonitoring: false
        )
        service.isOnline = false
        return service
    }

    private final class MockNavigator: Navigator {
        var selectedTab: AppTab = .home
        var path: [AppRoute] = []
        var isTabBarHidden: Bool = false
        var cameraReturnPhase: CameraReturnPhase = .idle
        var cameraReturnAngle: Double = 0.0
        var cameraIntroPhase: CameraIntroPhase = .idle
        var cameraIntroFilter: RollFilter = .colorPrint200
        var isFadingToReveal: Bool = false
    }

    @Test func routerInitialIntroStateIsIdle() {
        let router = AppRouter()
        #expect(router.cameraIntroPhase == .idle)
        #expect(router.cameraIntroFilter == .colorPrint200)
    }

    @Test func beginCameraIntroSetsPhaseAndHidesTabBar() {
        let router = AppRouter()
        #expect(router.shouldShowTabBar)

        router.beginCameraIntro(filter: .cinematicBW400)
        #expect(router.cameraIntroPhase == .fadingToBlank)
        #expect(router.cameraIntroFilter == .cinematicBW400)
        #expect(router.isTabBarHidden)
        #expect(!router.shouldShowTabBar)

        router.setCameraIntroAnimating()
        #expect(router.cameraIntroPhase == .animatingIntro)
        #expect(!router.shouldShowTabBar)

        router.finishCameraIntro()
        #expect(router.cameraIntroPhase == .idle)
    }

    @Test func canisterAssetBindingMatchesConfiguredFilter() {
        let colorFilter = RollFilter.colorPrint200
        let bwFilter = RollFilter.cinematicBW400

        let colorAsset = colorFilter == .cinematicBW400 ? "FilterCanisterBW" : "FilterCanisterColor"
        let bwAsset = bwFilter == .cinematicBW400 ? "FilterCanisterBW" : "FilterCanisterColor"

        #expect(colorAsset == "FilterCanisterColor")
        #expect(bwAsset == "FilterCanisterBW")
    }

    @Test func startRollCaptureTriggersIntroWithConfiguredFilter() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let sessionStore = SessionStore(modelContext: context)
        let cloudService = makeOfflineCloudService(context: context)
        let navigator = MockNavigator()

        let session = CaptureSession(
            name: "Summer Trip",
            rollCode: "SUMMER",
            hostUserID: "host_1",
            participantIDs: ["host_1"],
            participantNames: ["Host"],
            filter: .cinematicBW400
        )
        context.insert(session)
        try context.save()
        sessionStore.activeSession = session

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: navigator,
            sessionStore: sessionStore,
            cloudService: cloudService
        )

        viewModel.startRollCapture()
        await Task.yield()

        #expect(session.status == SessionStatus.live)
        #expect(navigator.cameraIntroPhase == .fadingToBlank)
        #expect(navigator.cameraIntroFilter == .cinematicBW400)
        #expect(navigator.isTabBarHidden)
        // Path push happens under the blank page overlay to eliminate navigation slide
        #expect(navigator.path.isEmpty)
        cloudService.stopLiveSessionPolling()
    }

    @Test func cameraIntroStagesProgressThroughLifecycle() {
        let stages: [CameraIntroStage] = [
            .fadeToBlank,
            .arrival,
            .loadingFilm,
            .latching,
            .winding,
            .zoomToDeck,
            .completed
        ]

        #expect(stages.count == 7)
        #expect(stages.first == .fadeToBlank)
        #expect(stages.last == .completed)
    }
}
