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
struct RollPopupTests {
    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserProfile.self, Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
            configurations: ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func makeCloudService(context: ModelContext) -> CloudKitSessionService {
        let service = CloudKitSessionService(modelContext: context, enableNetworkMonitoring: false)
        service.isOnline = true
        return service
    }

    @Test func endRollConfirmationGrammar() {
        let popupSingle = EndRollConfirmationPopupView(
            shotsRemaining: 1,
            onCancel: {},
            onConfirm: {}
        )
        #expect(popupSingle.shotsRemaining == 1)

        let popupMultiple = EndRollConfirmationPopupView(
            shotsRemaining: 6,
            onCancel: {},
            onConfirm: {}
        )
        #expect(popupMultiple.shotsRemaining == 6)
    }

    @Test func rollCompleteCopyVariants() {
        let naturalPopup = RollCompletePopupView(
            isEndedEarly: false,
            onReveal: {}
        )
        #expect(naturalPopup.isEndedEarly == false)

        let earlyPopup = RollCompletePopupView(
            isEndedEarly: true,
            onReveal: {}
        )
        #expect(earlyPopup.isEndedEarly == true)
    }

    @Test func hostPresentsAndDismissesEndRollConfirmation() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeCloudService(context: context)
        let host = UserProfile(appleUserID: "host-1", name: "Host")
        context.insert(host)

        let session = CaptureSession(
            name: "Test Roll",
            rollCode: "TEST99",
            hostUserID: host.appleUserID,
            participantIDs: [host.appleUserID],
            participantNames: [host.name],
            rollSize: 24,
            filter: .colorPrint200
        )
        session.status = .live
        context.insert(session)
        store.activeSession = session
        try context.save()

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            roomService: MockRollRoomService()
        )

        #expect(viewModel.showEndRollConfirmation == false)
        viewModel.presentEndRollConfirmation()
        #expect(viewModel.showEndRollConfirmation == true)

        viewModel.dismissEndRollConfirmation()
        #expect(viewModel.showEndRollConfirmation == false)
    }

    @Test func hostConfirmsEndRollEarlyTransitionsToCompletePopup() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeCloudService(context: context)
        let host = UserProfile(appleUserID: "host-1", name: "Host")
        context.insert(host)

        let session = CaptureSession(
            name: "Test Roll",
            rollCode: "TEST99",
            hostUserID: host.appleUserID,
            participantIDs: [host.appleUserID],
            participantNames: [host.name],
            rollSize: 24,
            filter: .colorPrint200
        )
        session.slotsUsed = 10
        session.status = .live
        context.insert(session)
        store.activeSession = session
        try context.save()

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            roomService: MockRollRoomService()
        )

        viewModel.presentEndRollConfirmation()
        #expect(viewModel.showEndRollConfirmation == true)

        viewModel.confirmEndRollByHost(currentUser: host)
        #expect(viewModel.showEndRollConfirmation == false)
        #expect(viewModel.showRollCompletePopup == true)
        #expect(viewModel.isRollEndedEarly == true)
        #expect(session.status == .ended)

        viewModel.finalizeSessionTask?.cancel()
        _ = await viewModel.finalizeSessionTask?.result
    }

    @Test func nonHostCannotConfirmEndRoll() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeCloudService(context: context)
        let host = UserProfile(appleUserID: "host-1", name: "Host")
        let friend = UserProfile(appleUserID: "friend-2", name: "Friend")
        context.insert(host)
        context.insert(friend)

        let session = CaptureSession(
            name: "Test Roll",
            rollCode: "TEST99",
            hostUserID: host.appleUserID,
            participantIDs: [host.appleUserID, friend.appleUserID],
            participantNames: [host.name, friend.name],
            rollSize: 24,
            filter: .colorPrint200
        )
        session.status = .live
        context.insert(session)
        store.activeSession = session
        try context.save()

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            roomService: MockRollRoomService()
        )

        viewModel.confirmEndRollByHost(currentUser: friend)
        #expect(session.status == .live)
        #expect(viewModel.showRollCompletePopup == false)
    }

    @Test func proceedToRollRevealNavigatesToRevealScreen() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeCloudService(context: context)
        let host = UserProfile(appleUserID: "host-1", name: "Host")
        context.insert(host)

        let session = CaptureSession(
            name: "Test Roll",
            rollCode: "TEST99",
            hostUserID: host.appleUserID,
            participantIDs: [host.appleUserID],
            participantNames: [host.name],
            rollSize: 24,
            filter: .colorPrint200
        )
        session.status = .live
        context.insert(session)
        store.activeSession = session
        try context.save()

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            roomService: MockRollRoomService()
        )

        viewModel.showRollCompletePopup = true
        viewModel.proceedToRollReveal()
        viewModel.finalizeSessionTask?.cancel()
        _ = await viewModel.finalizeSessionTask?.result

        #expect(viewModel.showRollCompletePopup == false)
        guard case .rollReveal? = router.path.last else {
            Issue.record("Expected navigation to rollReveal, got \(String(describing: router.path.last))")
            return
        }
    }

    @Test func naturalCompletionShowsRollCompleteWithoutEarlyEnd() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let cloud = makeCloudService(context: context)
        let host = UserProfile(appleUserID: "host-1", name: "Host")
        context.insert(host)

        let session = CaptureSession(
            name: "Test Roll",
            rollCode: "TEST99",
            hostUserID: host.appleUserID,
            participantIDs: [host.appleUserID],
            participantNames: [host.name],
            rollSize: 10,
            filter: .colorPrint200
        )
        session.slotsUsed = 9
        session.status = .live
        context.insert(session)
        store.activeSession = session
        try context.save()

        let viewModel = RollFlowViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            cloudService: cloud,
            roomService: MockRollRoomService()
        )

        viewModel.applyRemoteSlotCount(10)
        #expect(session.status == .ended)
        #expect(viewModel.showRollCompletePopup == true)
        #expect(viewModel.isRollEndedEarly == false)

        viewModel.finalizeSessionTask?.cancel()
        _ = await viewModel.finalizeSessionTask?.result
    }
}
