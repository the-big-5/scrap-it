import Foundation
import SwiftData
import Testing
@testable import ScrapIt

@MainActor
final class MockRollSlotRealtimeService: RollSlotRealtimeProviding {
    private(set) var connectedRollCodes: [String] = []
    private(set) var broadcastedCounts: [Int] = []
    private(set) var disconnectCount: Int = 0
    private var slotUpdateHandler: (@MainActor @Sendable (Int) -> Void)?

    func connect(
        rollCode: String,
        onSlotUpdate: @escaping @MainActor @Sendable (Int) -> Void
    ) async {
        connectedRollCodes.append(rollCode)
        slotUpdateHandler = onSlotUpdate
    }

    func broadcastSlotCount(_ slotsUsed: Int) async {
        broadcastedCounts.append(slotsUsed)
    }

    func disconnect() async {
        disconnectCount += 1
        slotUpdateHandler = nil
    }

    func simulateIncomingSlotCount(_ slotsUsed: Int) {
        slotUpdateHandler?(slotsUsed)
    }
}

@MainActor
struct RollRealtimeServiceTests {
    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserProfile.self, Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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

    // MARK: - SupabaseConfig

    @Test func supabaseConfigRejectsMissingEmptyAndPlaceholderValues() {
        #expect(SupabaseConfig.parse([:]) == nil)
        #expect(SupabaseConfig.parse([
            "SUPABASE_URL": "",
            "SUPABASE_ANON_KEY": ""
        ]) == nil)
        #expect(SupabaseConfig.parse([
            "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
            "SUPABASE_ANON_KEY": "YOUR_SUPABASE_ANON_KEY"
        ]) == nil)
        #expect(SupabaseConfig.parse([
            "SUPABASE_URL": "https://<project>.supabase.co",
            "SUPABASE_ANON_KEY": "valid-anon-key"
        ]) == nil)
        #expect(SupabaseConfig.parse([
            "SUPABASE_URL": "ftp://example.supabase.co",
            "SUPABASE_ANON_KEY": "valid-anon-key"
        ]) == nil)
    }

    @Test func supabaseConfigParsesValidCredentials() {
        let parsed = SupabaseConfig.parse([
            "SUPABASE_URL": "  https://abcdefghijkl.supabase.co  ",
            "SUPABASE_ANON_KEY": "  eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9  "
        ])
        #expect(parsed == SupabaseConfig(
            url: URL(string: "https://abcdefghijkl.supabase.co")!,
            anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        ))
    }

    @Test func supabaseConfigLoadReturnsNilForMissingOrTemplatePlist() {
        #expect(SupabaseConfig.load(resourceName: "NonExistentSupabasePlist") == nil)
        #expect(SupabaseConfig.load(resourceName: "SupabaseSecretsExample") == nil)
    }

    // MARK: - Payload Decoding

    @Test func decodeSlotBroadcastHandlesWrappedAndDirectPayloads() {
        let wrappedJSON = Data("""
        {"type":"broadcast","event":"slot_taken","payload":{"slotsUsed":12}}
        """.utf8)
        #expect(
            SupabaseRollSlotRealtimeService.decodeSlotBroadcast(from: wrappedJSON)
                == RollSlotBroadcast(slotsUsed: 12)
        )

        let directJSON = Data("""
        {"slotsUsed":7}
        """.utf8)
        #expect(
            SupabaseRollSlotRealtimeService.decodeSlotBroadcast(from: directJSON)
                == RollSlotBroadcast(slotsUsed: 7)
        )

        let malformedJSON = Data("""
        {"event":"slot_taken","payload":{"other":true}}
        """.utf8)
        #expect(SupabaseRollSlotRealtimeService.decodeSlotBroadcast(from: malformedJSON) == nil)
    }

    // MARK: - RollFlowViewModel Camera-Only Slot Sync

    @Test func viewModelDefaultsToNoopWhenSecretsUnconfigured() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)

        let viewModel = RollFlowViewModel(
            modelContext: context,
            sessionStore: store,
            cloudService: cloud
        )
        #expect(viewModel.realtimeService is NoopRollSlotRealtimeService)
    }

    @Test func cameraLifecycleConnectsAndDisconnectsRealtime() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let mockRealtime = MockRollSlotRealtimeService()

        let session = CaptureSession(
            name: "Beach Roll",
            rollCode: "AB12CD",
            hostUserID: "apple-host",
            participantIDs: ["apple-host"],
            participantNames: ["Host"],
            rollSize: 24,
            slotsUsed: 0,
            status: .live
        )
        context.insert(session)
        store.activeSession = session

        let viewModel = RollFlowViewModel(
            modelContext: context,
            sessionStore: store,
            cloudService: cloud,
            realtimeService: mockRealtime
        )

        viewModel.cameraDidAppear()
        await Task.yield()
        await Task.yield()
        #expect(mockRealtime.connectedRollCodes == ["AB12CD"])

        viewModel.cameraDidDisappear()
        await Task.yield()
        await Task.yield()
        #expect(mockRealtime.disconnectCount == 1)
    }

    @Test func recordCapturedShotBroadcastsSlotCountImmediately() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let mockRealtime = MockRollSlotRealtimeService()
        let user = UserProfile(appleUserID: "apple-host", name: "Host")

        let session = CaptureSession(
            name: "Night Walk",
            rollCode: "XY98ZT",
            hostUserID: user.appleUserID,
            participantIDs: [user.appleUserID],
            participantNames: [user.name],
            rollSize: 24,
            slotsUsed: 0,
            status: .live
        )
        context.insert(session)
        store.activeSession = session

        let viewModel = RollFlowViewModel(
            modelContext: context,
            sessionStore: store,
            cloudService: cloud,
            realtimeService: mockRealtime
        )

        let captured = await viewModel.recordCapturedShot(
            imageData: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            currentUser: user
        )
        #expect(captured != nil)
        #expect(viewModel.takenShotsText == "01")

        await Task.yield()
        await Task.yield()
        #expect(mockRealtime.broadcastedCounts == [1])
    }

    @Test func incomingSlotJumpUpdatesCounterIdempotently() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let mockRealtime = MockRollSlotRealtimeService()

        let session = CaptureSession(
            name: "Roadtrip",
            rollCode: "KL34MN",
            hostUserID: "apple-host",
            participantIDs: ["apple-host", "apple-guest"],
            participantNames: ["Host", "Guest"],
            rollSize: 24,
            slotsUsed: 0,
            status: .live
        )
        context.insert(session)
        store.activeSession = session

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            realtimeService: mockRealtime
        )

        viewModel.cameraDidAppear()
        await Task.yield()
        await Task.yield()

        #expect(viewModel.takenShotsText == "00")

        // Remote collaborator jumps roll to 12/24
        mockRealtime.simulateIncomingSlotCount(12)
        #expect(viewModel.takenShotsText == "12")
        #expect(session.status == .live)

        // Stale lower or duplicate broadcasts must not regress counter
        mockRealtime.simulateIncomingSlotCount(5)
        #expect(viewModel.takenShotsText == "12")
        mockRealtime.simulateIncomingSlotCount(12)
        #expect(viewModel.takenShotsText == "12")
    }

    @Test func incomingFinalSlotEndsRollAndOpensScrapbook() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let mockRealtime = MockRollSlotRealtimeService()

        let session = CaptureSession(
            name: "Concert",
            rollCode: "FN24AL",
            hostUserID: "apple-host",
            participantIDs: ["apple-host", "apple-guest"],
            participantNames: ["Host", "Guest"],
            rollSize: 24,
            slotsUsed: 23,
            status: .live
        )
        context.insert(session)
        store.activeSession = session

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            realtimeService: mockRealtime
        )

        viewModel.cameraDidAppear()
        await Task.yield()
        await Task.yield()

        mockRealtime.simulateIncomingSlotCount(24)
        await Task.yield()
        await Task.yield()

        #expect(session.status == .ended)
        #expect(viewModel.takenShotsText == "24")
        #expect(store.activeScrapbook != nil)
        #expect(session.createdScrapbookID == store.activeScrapbook?.id)
        if let scrapbookID = store.activeScrapbook?.id {
            #expect(router.path == [.scrapbookGrid(scrapbookID)])
        }
        #expect(mockRealtime.disconnectCount == 1)
    }

    @Test func lobbyAndStartRollDoNotTouchRealtimeBeforeCameraAppears() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let mockRealtime = MockRollSlotRealtimeService()
        let host = UserProfile(appleUserID: "apple-host", name: "Host")

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            realtimeService: mockRealtime
        )

        viewModel.draftRollName = "Picnic"
        viewModel.draftShotCount = 24
        viewModel.createLobbySession(currentUser: host)
        viewModel.startRollCapture()
        await Task.yield()

        #expect(mockRealtime.connectedRollCodes.isEmpty)
        #expect(mockRealtime.broadcastedCounts.isEmpty)
        cloud.stopLiveSessionPolling()
    }
}
