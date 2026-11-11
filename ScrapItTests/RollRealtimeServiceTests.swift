import CloudKit
import Foundation
import SwiftData
import Testing
import UIKit
@testable import ScrapIt

private final class MockRollRoomService: RollRoomServicing {
    var lastErrorDescription: String?
    func createRoom(_ draft: RoomDraft) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func joinRoom(code: String, as user: RoomParticipant) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func acceptShare(_ metadata: CKShare.Metadata, as user: RoomParticipant) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func fetchRoom(code: String, zoneOwnerName: String?) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func removeParticipant(userID: String, fromRoom code: String) async throws {}
    func leaveRoom(code: String, zoneOwnerName: String, userID: String) async throws {}
    func deleteRoom(code: String) async throws {}
    func listRooms() async throws -> [RoomSnapshot] { [] }
    func downloadShotPayload(recordName: String) async throws -> Data { throw RoomError.notFound }
}

@MainActor
final class MockRollSlotRealtimeService: RollSlotRealtimeProviding {
    private(set) var connectedRollCodes: [String] = []
    private(set) var broadcastedCounts: [Int] = []
    private(set) var disconnectCount: Int = 0
    private(set) var broadcastRollEndedCount: Int = 0
    private var slotUpdateHandler: (@MainActor @Sendable (Int) -> Void)?
    private var rollEndedHandler: (@MainActor @Sendable () -> Void)?

    func connect(
        rollCode: String,
        onSlotUpdate: @escaping @MainActor @Sendable (Int) -> Void,
        onRollEnded: (@MainActor @Sendable () -> Void)? = nil
    ) async {
        connectedRollCodes.append(rollCode)
        slotUpdateHandler = onSlotUpdate
        rollEndedHandler = onRollEnded
    }

    func broadcastSlotCount(_ slotsUsed: Int) async {
        broadcastedCounts.append(slotsUsed)
    }

    func broadcastRollEnded() async {
        broadcastRollEndedCount += 1
    }

    func disconnect() async {
        disconnectCount += 1
        slotUpdateHandler = nil
        rollEndedHandler = nil
    }

    func simulateIncomingSlotCount(_ slotsUsed: Int) {
        slotUpdateHandler?(slotsUsed)
    }

    func simulateIncomingRollEnded() {
        rollEndedHandler?()
    }
}

@MainActor
struct RollRealtimeServiceTests {
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

    @Test func viewModelDefaultsToAppropriateRealtimeService() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)

        let viewModel = RollFlowViewModel(
            modelContext: context,
            sessionStore: store,
            cloudService: cloud,
            roomService: MockRollRoomService()
        )
        if SupabaseConfig.load() != nil {
            #expect(viewModel.realtimeService is SupabaseRollSlotRealtimeService)
        } else {
            #expect(viewModel.realtimeService is NoopRollSlotRealtimeService)
        }
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
            roomService: MockRollRoomService(),
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
            roomService: MockRollRoomService(),
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
            roomService: MockRollRoomService(),
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
            roomService: MockRollRoomService(),
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
        #expect(viewModel.showRollCompletePopup == true)

        viewModel.proceedToRollReveal()
        viewModel.finalizeSessionTask?.cancel()
        _ = await viewModel.finalizeSessionTask?.result

        #expect(store.activeScrapbook != nil)
        #expect(session.createdScrapbookID == store.activeScrapbook?.id)
        if let scrapbookID = store.activeScrapbook?.id {
            // Change 021: the photo reveal comes first.
            #expect(router.path == [.rollReveal(scrapbookID)])
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
            roomService: MockRollRoomService(),
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

@MainActor
struct ScrapbookPresenceAvatarTests {
    @Test func collaboratorPresenceEncodesAndDecodesAvatarData() throws {
        let sampleAvatar = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let presence = CollaboratorPresence(
            id: "user-1",
            name: "Olifian Lepin",
            colorHex: "#2F80ED",
            currentPageIndex: 1,
            avatarData: sampleAvatar
        )

        let encoded = try JSONEncoder().encode(presence)
        let decoded = try JSONDecoder().decode(CollaboratorPresence.self, from: encoded)

        #expect(decoded.id == "user-1")
        #expect(decoded.name == "Olifian Lepin")
        #expect(decoded.avatarData == sampleAvatar)
    }

    @Test func connectRealtimeAttachesCompressedAvatarThumbnail() async throws {
        let container = try ModelContainer(
            for: UserProfile.self, Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
            ScrapbookPage.self, ScrapbookItem.self, StickerSheet.self,
            configurations: ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = container.mainContext
        let store = SessionStore(modelContext: context)
        let scrapbook = Scrapbook(title: "Trip", sourceSessionID: UUID())
        context.insert(scrapbook)
        try context.save()

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        let rawAvatar = renderer.image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }.pngData()!

        let user = UserProfile(appleUserID: "user-1", name: "Olifian", avatarData: rawAvatar)
        let mockRealtime = MockScrapbookRealtimeService()
        let viewModel = ScrapbookViewModel(
            modelContext: context,
            sessionStore: store,
            scrapbookID: scrapbook.id,
            currentUser: user,
            realtimeService: mockRealtime
        )

        await viewModel.connectRealtime()

        let sentAvatar = try #require(mockRealtime.currentUser?.avatarData)
        #expect(!sentAvatar.isEmpty)
        let source = CGImageSourceCreateWithData(sentAvatar as CFData, nil)
        let props = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
        let width = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = props?[kCGImagePropertyPixelHeight] as? Int ?? 0
        #expect(max(width, height) <= 80)
    }
}
