import CloudKit
import Foundation
import SwiftData
import SwiftUI
import Testing
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

@Suite(.serialized)
@MainActor
struct ShotsLeftSyncIndicatorTests {
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

    @Test func dialViewAccessibilityReflectsSyncState() {
        let restingDial = ShotsLeftDialView(shotsRemaining: 24, totalShots: 24, isSyncing: false)
        #expect(!restingDial.isSyncing)
        #expect(restingDial.safeShots == 24)

        let syncingDial = ShotsLeftDialView(shotsRemaining: 24, totalShots: 24, isSyncing: true)
        #expect(syncingDial.isSyncing)
        #expect(syncingDial.safeShots == 24)
    }

    @Test func syncIndicatorViewRendersCleanly() {
        let hostingController = UIHostingController(rootView: ShotsLeftSyncIndicatorView())
        #expect(hostingController.view != nil)
    }

    @Test func continuousHumHapticMethodsExecuteSafely() {
        HapticService.shared.startContinuousHum()
        HapticService.shared.stopContinuousHum()
        #expect(!HapticService.shared.isContinuousHumming)

        HapticService.shared.playDialDecrement()
    }

    @Test func syncStateHoldsRemainingCountUntilClaimFinishes() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let mockRealtime = MockRollSlotRealtimeService()
        let user = UserProfile(appleUserID: "user-sync", name: "SyncTester")
        context.insert(user)

        let session = CaptureSession(
            name: "Sunset",
            rollCode: "SUNSET",
            hostUserID: user.appleUserID,
            participantIDs: [user.appleUserID],
            participantNames: [user.name],
            rollSize: 24,
            slotsUsed: 10,
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

        // Baseline: before taking shot
        #expect(!viewModel.isSyncingShot)
        #expect(viewModel.shotsRemaining == 14)

        // Capture shot: triggers optimistic save & in-flight claim
        let photo = await viewModel.recordCapturedShot(
            imageData: Data([0x01, 0x02]),
            currentUser: user
        )
        #expect(photo != nil)

        // While claim is in flight, isSyncingShot is true and dial holds count at 14
        #expect(viewModel.isSyncingShot)
        #expect(viewModel.shotsRemaining == 14)

        // Wait for claim task to resolve
        await viewModel.lastSlotClaimTask?.value
        await Task.yield()

        // After claim confirms, sync indicator turns off and shotsRemaining decrements to 13
        #expect(!viewModel.isSyncingShot)
        #expect(viewModel.shotsRemaining == 13)
        #expect(session.slotsUsed == 11)
    }

    @Test func finalizeSessionResetsSyncState() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let user = UserProfile(appleUserID: "user-end", name: "EndTester")
        context.insert(user)

        let session = CaptureSession(
            name: "Final",
            rollCode: "FINALS",
            hostUserID: user.appleUserID,
            participantIDs: [user.appleUserID],
            participantNames: [user.name],
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
            roomService: MockRollRoomService()
        )

        _ = await viewModel.recordCapturedShot(
            imageData: Data([0xFF]),
            currentUser: user
        )

        viewModel.finalizeSessionAndOpenScrapbook()
        #expect(!viewModel.isSyncingShot)
        await viewModel.lastSlotClaimTask?.value
        await viewModel.finalizeSessionTask?.value
        await Task.yield()
    }

    @Test func shutterTappedProcessesShotAndResolvesSyncState() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let user = UserProfile(appleUserID: "user-tap", name: "TapTester")
        context.insert(user)

        let session = CaptureSession(
            name: "TapRoll",
            rollCode: "TAPROL",
            hostUserID: user.appleUserID,
            participantIDs: [user.appleUserID],
            participantNames: [user.name],
            rollSize: 24,
            slotsUsed: 5,
            status: .live
        )
        context.insert(session)
        store.activeSession = session

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            roomService: MockRollRoomService()
        )

        #expect(!viewModel.isSyncingShot)
        #expect(viewModel.shotsRemaining == 19)

        await viewModel.shutterTapped(currentUser: user)
        await viewModel.lastSlotClaimTask?.value
        await Task.yield()

        #expect(!viewModel.isSyncingShot)
        #expect(viewModel.shotsRemaining == 18)
        #expect(session.slotsUsed == 6)
    }
}
