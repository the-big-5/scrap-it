import CloudKit
import Foundation
import SwiftData
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
struct OptimisticShutterSlotClaimTests {
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

    @Test func optimisticShutterReturnsInstantlyAndIncrementsLocalSlot() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let mockRealtime = MockRollSlotRealtimeService()
        let user = UserProfile(appleUserID: "user-alpha", name: "Alpha")
        context.insert(user)

        let session = CaptureSession(
            name: "Golden Hour",
            rollCode: "GOLDEN",
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

        let photo = await viewModel.recordCapturedShot(
            imageData: Data([0xAA, 0xBB]),
            currentUser: user
        )

        // Verifies optimistic UI update happens immediately
        #expect(photo != nil)
        #expect(session.slotsUsed == 11)
        #expect(viewModel.takenShotsText == "11")

        // Wait for claim task
        await viewModel.lastSlotClaimTask?.value
        await Task.yield()

        #expect(mockRealtime.broadcastedCounts.contains(11))
    }

    @Test func lastSlotRaceDropsPhotoWhenConflictSimulated() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let mockRealtime = MockRollSlotRealtimeService()
        let user = UserProfile(appleUserID: "user-beta", name: "Beta")
        context.insert(user)

        let session = CaptureSession(
            name: "Night Out",
            rollCode: "NIGHTS",
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
            roomService: MockRollRoomService(),
            realtimeService: mockRealtime
        )

        // Capture shot with conflict simulated on the final slot
        let photo = await viewModel.recordCapturedShot(
            imageData: Data([0xCC, 0xDD]),
            currentUser: user,
            simulateLastSlotConflict: true
        )

        #expect(photo != nil)

        // Await background resolution task
        await viewModel.lastSlotClaimTask?.value
        await Task.yield()

        // Per Spec F3: the rejected photo is dropped from ModelContext
        #expect(photo?.modelContext == nil)
        #expect(viewModel.showLastSlotRaceAlert == true)
        #expect(session.slotsUsed == 24)
        #expect(session.status == .ended)
    }

    @Test func alreadyEndedRollRejectsImmediately() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeOfflineCloudService(context: context)
        let user = UserProfile(appleUserID: "user-gamma", name: "Gamma")
        context.insert(user)

        let session = CaptureSession(
            name: "Done Roll",
            rollCode: "CLOSED",
            hostUserID: user.appleUserID,
            participantIDs: [user.appleUserID],
            participantNames: [user.name],
            rollSize: 24,
            slotsUsed: 24,
            status: .ended
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

        let photo = await viewModel.recordCapturedShot(
            imageData: Data([0xEE, 0xFF]),
            currentUser: user
        )

        #expect(photo == nil)
        #expect(viewModel.showLastSlotRaceAlert == true)
    }
}
