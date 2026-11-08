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

@MainActor
struct RollBatchUploadTests {
    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserProfile.self, Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
            configurations: ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func makeCloudService(context: ModelContext, isOnline: Bool = true) -> CloudKitSessionService {
        let service = CloudKitSessionService(
            modelContext: context,
            enableNetworkMonitoring: false
        )
        service.isOnline = isOnline
        return service
    }

    @Test func capturingShotsDuringLiveRollDoesNotUploadToCloudKit() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeCloudService(context: context, isOnline: true)
        let user = UserProfile(appleUserID: "apple-user-1", name: "Alex")
        context.insert(user)

        let session = CaptureSession(
            name: "Summer Trip",
            rollCode: "SUMMER",
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
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            roomService: MockRollRoomService()
        )

        let photo = await viewModel.recordCapturedShot(
            imageData: Data([0xDE, 0xAD, 0xBE, 0xEF]),
            currentUser: user
        )

        // Photo must be saved locally with isSyncedToCloud == false
        #expect(photo != nil)
        #expect(photo?.isSyncedToCloud == false)
        #expect(session.slotsUsed == 1)
        #expect(session.status == .live)
        // Queued offline count only counts ended sessions, so active roll photos don't inflate offline queue
        #expect(cloud.queuedOfflineCount == 0)
    }

    @Test func finalizingFullRollTriggersBatchUploadOfItsPhotos() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeCloudService(context: context, isOnline: true)
        let user = UserProfile(appleUserID: "apple-user-1", name: "Alex")
        context.insert(user)

        let session = CaptureSession(
            name: "Final Roll",
            rollCode: "FINISH",
            hostUserID: user.appleUserID,
            participantIDs: [user.appleUserID],
            participantNames: [user.name],
            rollSize: 2,
            slotsUsed: 1,
            status: .live
        )
        context.insert(session)
        store.activeSession = session

        // Insert first shot previously captured
        let photo1 = ScrapPhoto(
            imageData: Data([0x01, 0x02]),
            caption: "Shot 1",
            authorID: user.appleUserID,
            authorName: user.name,
            timestamp: .now,
            sourceSessionID: session.id,
            isSyncedToCloud: false
        )
        context.insert(photo1)
        try context.save()

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            roomService: MockRollRoomService()
        )

        // Capture 2nd shot, which claims slot 2/2 and reaches rollFinished
        let photo2 = await viewModel.recordCapturedShot(
            imageData: Data([0x03, 0x04]),
            currentUser: user
        )

        #expect(photo2 != nil)
        #expect(session.slotsUsed == 2)
        #expect(session.status == .ended)

        // Wait for background batch upload in finalizeSessionAndOpenScrapbook
        for _ in 0..<50 where !photo1.isSyncedToCloud || photo2?.isSyncedToCloud != true {
            try? await Task.sleep(for: .milliseconds(20))
        }

        #expect(photo1.isSyncedToCloud == true)
        #expect(photo2?.isSyncedToCloud == true)
    }

    @Test func manualEarlyHostEndTriggersBatchUpload() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeCloudService(context: context, isOnline: true)
        let host = UserProfile(appleUserID: "host-apple-id", name: "Host")
        context.insert(host)

        let session = CaptureSession(
            name: "Early End Roll",
            rollCode: "EARLY1",
            hostUserID: host.appleUserID,
            participantIDs: [host.appleUserID],
            participantNames: [host.name],
            rollSize: 24,
            slotsUsed: 3,
            status: .live
        )
        context.insert(session)
        store.activeSession = session

        // 3 un-synced local photos
        let p1 = ScrapPhoto(imageData: Data([1]), caption: "", authorID: host.appleUserID, authorName: host.name, timestamp: .now, sourceSessionID: session.id, isSyncedToCloud: false)
        let p2 = ScrapPhoto(imageData: Data([2]), caption: "", authorID: host.appleUserID, authorName: host.name, timestamp: .now, sourceSessionID: session.id, isSyncedToCloud: false)
        let p3 = ScrapPhoto(imageData: Data([3]), caption: "", authorID: host.appleUserID, authorName: host.name, timestamp: .now, sourceSessionID: session.id, isSyncedToCloud: false)
        context.insert(p1)
        context.insert(p2)
        context.insert(p3)
        try context.save()

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            roomService: MockRollRoomService()
        )

        viewModel.endSessionManuallyByHost(currentUser: host)
        #expect(session.status == .ended)

        // Wait for background upload task in finalizeSessionAndOpenScrapbook
        for _ in 0..<50 where !p1.isSyncedToCloud || !p2.isSyncedToCloud || !p3.isSyncedToCloud {
            try? await Task.sleep(for: .milliseconds(20))
        }

        #expect(p1.isSyncedToCloud == true)
        #expect(p2.isSyncedToCloud == true)
        #expect(p3.isSyncedToCloud == true)
    }

    @Test func launchSyncIgnoresPhotosFromUnendedSessions() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let cloud = makeCloudService(context: context, isOnline: true)

        let activeSession = CaptureSession(
            name: "Active Roll",
            rollCode: "ACTIVE",
            hostUserID: "user-1",
            participantIDs: ["user-1"],
            participantNames: ["User"],
            rollSize: 24,
            slotsUsed: 5,
            status: .live
        )
        let endedSession = CaptureSession(
            name: "Ended Roll",
            rollCode: "ENDED1",
            hostUserID: "user-1",
            participantIDs: ["user-1"],
            participantNames: ["User"],
            rollSize: 24,
            slotsUsed: 24,
            status: .ended
        )
        context.insert(activeSession)
        context.insert(endedSession)

        let activePhoto = ScrapPhoto(imageData: Data([10]), caption: "", authorID: "user-1", authorName: "User", timestamp: .now, sourceSessionID: activeSession.id, isSyncedToCloud: false)
        let endedPhoto = ScrapPhoto(imageData: Data([20]), caption: "", authorID: "user-1", authorName: "User", timestamp: .now, sourceSessionID: endedSession.id, isSyncedToCloud: false)
        context.insert(activePhoto)
        context.insert(endedPhoto)
        try context.save()

        cloud.updateQueuedCount()
        // Only the ended session's photo is counted as queued for offline sync
        #expect(cloud.queuedOfflineCount == 1)

        await cloud.syncPendingOfflinePhotos()

        // Active session's photo remains un-synced
        #expect(activePhoto.isSyncedToCloud == false)
        // Ended session's photo is synced
        #expect(endedPhoto.isSyncedToCloud == true)
        #expect(cloud.queuedOfflineCount == 0)
    }
}
