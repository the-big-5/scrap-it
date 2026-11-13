import CloudKit
import Foundation
import SwiftData
import Testing
import UIKit
@testable import ScrapIt

private final class FakeNavigator: Navigator {
    var selectedTab: AppTab = .home
    var path: [AppRoute] = []
    var isTabBarHidden = false
    var cameraReturnPhase: CameraReturnPhase = .idle
    var cameraReturnAngle: Double = 0.0
}

private final class FakeRoomService: RollRoomServicing {
    var lastErrorDescription: String?
    var createError: RoomError?
    var rooms: [String: RoomSnapshot] = [:]
    var joinError: RoomError?
    var fetchError: RoomError?
    var created: [RoomDraft] = []
    var updated: [(user: RoomParticipant, code: String)] = []
    var removed: [(userID: String, code: String)] = []
    var left: [(code: String, owner: String, userID: String)] = []
    var deleted: [String] = []
    let shareURL = URL(string: "https://www.icloud.com/share/0abcDEF")!

    func createRoom(_ draft: RoomDraft) async throws -> RoomSnapshot {
        created.append(draft)
        if let createError {
            lastErrorDescription = "CKError 15 (serverRejectedRequest)"
            throw createError
        }
        let snapshot = RoomSnapshot(
            sessionID: draft.sessionID, rollCode: draft.rollCode, name: draft.name, hostUserID: draft.host.userID,
            rollSize: draft.rollSize, slotsUsed: 0, filterRaw: draft.filterRaw, statusRaw: SessionStatus.waiting.rawValue,
            participants: [draft.host], shareURL: shareURL, zoneOwnerName: nil, rollKey: draft.rollKey
        )
        rooms[draft.rollCode] = snapshot
        return snapshot
    }

    /// Keeps a join waiting, like a slow CloudKit answer (change 024).
    var joinDelay: Duration?

    func joinRoom(code: String, as user: RoomParticipant) async throws -> RoomSnapshot {
        if let joinDelay { try? await Task.sleep(for: joinDelay) }
        if let joinError { throw joinError }
        guard var room = rooms[code] else { throw RoomError.notFound }
        if room.hostUserID == user.userID {
            // Same iCloud as the host: own room, nobody added.
            return room
        }
        room.zoneOwnerName = "_hostOwner"
        if !room.participants.contains(where: { $0.userID == user.userID }) {
            room.participants.append(user)
        }
        rooms[code] = room
        return room
    }

    func acceptShare(_ metadata: CKShare.Metadata, as user: RoomParticipant) async throws -> RoomSnapshot {
        throw RoomError.unavailable
    }

    func fetchRoom(code: String, zoneOwnerName: String?) async throws -> RoomSnapshot {
        if let fetchError { throw fetchError }
        guard var room = rooms[code] else { throw RoomError.deleted }
        room.zoneOwnerName = zoneOwnerName
        return room
    }

    func updateParticipant(_ user: RoomParticipant, inRoom code: String, zoneOwnerName: String?) async throws {
        updated.append((user, code))
        guard var room = rooms[code],
              let index = room.participants.firstIndex(where: { $0.userID == user.userID }) else { return }
        room.participants[index] = user
        rooms[code] = room
    }

    func removeParticipant(userID: String, fromRoom code: String) async throws {
        removed.append((userID, code))
        rooms[code]?.participants.removeAll { $0.userID == userID }
    }

    func leaveRoom(code: String, zoneOwnerName: String, userID: String) async throws {
        left.append((code, zoneOwnerName, userID))
    }

    func deleteRoom(code: String) async throws {
        deleted.append(code)
        rooms[code] = nil
    }

    func listRooms() async throws -> [RoomSnapshot] { Array(rooms.values) }

    func downloadShotPayload(recordName: String) async throws -> Data { throw RoomError.notFound }
}

@MainActor
struct RollRoomTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    private let navigator = FakeNavigator()
    private let rooms = FakeRoomService()
    let host: UserProfile
    let guest: UserProfile

    init() throws {
        container = try ModelContainer(
            for: UserProfile.self, Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
            configurations: ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        host = UserProfile(appleUserID: "host-1", name: "Nabiel")
        guest = UserProfile(appleUserID: "guest-2", name: "Brian Chang")
        context.insert(host)
        context.insert(guest)
    }

    private func makeViewModel(online: Bool = true, store: SessionStore? = nil) -> RollFlowViewModel {
        let cloud = CloudKitSessionService(modelContext: context)
        cloud.isOnline = online
        return RollFlowViewModel(
            modelContext: context,
            navigator: navigator,
            sessionStore: store ?? SessionStore(modelContext: context),
            cloudService: cloud,
            roomService: rooms
        )
    }

    /// Create Roll needs a name and a shot count since change 081; tests that don't care get defaults.
    private func createLobby(_ vm: RollFlowViewModel, as user: UserProfile) {
        if vm.draftRollName.isEmpty { vm.draftRollName = "Roll" }
        if vm.draftShotCount == nil { vm.draftShotCount = 36 }
        vm.createLobbySession(currentUser: user)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func hostRoom(code: String = "N4B13L", status: SessionStatus = .waiting) {
        rooms.rooms[code] = RoomSnapshot(
            sessionID: UUID(), rollCode: code, name: "Bali '27", hostUserID: host.appleUserID, rollSize: 24,
            slotsUsed: 0, filterRaw: RollFilter.colorPrint200.rawValue, statusRaw: status.rawValue,
            participants: [RoomParticipant(userID: host.appleUserID, name: host.name)],
            shareURL: rooms.shareURL, zoneOwnerName: nil
        )
    }

    // MARK: - Share content

    private let content = RollInviteContent(
        rollName: "Bali '27",
        rollCode: "N4B13L",
        link: URL(string: "https://www.icloud.com/share/0abcDEF")!
    )

    @Test func airDropSharesTheLinkOnly() {
        #expect(content.item(for: .airDrop) as? URL == content.link)
    }

    @Test(arguments: [
        UIActivity.ActivityType.message,
        UIActivity.ActivityType("net.whatsapp.WhatsApp.ShareExtension"),
        UIActivity.ActivityType("ph.telegra.Telegraph.Share"),
    ])
    func messagingAppsGetTextWithTheLink(_ type: UIActivity.ActivityType) throws {
        let text = try #require(content.item(for: type) as? String)
        #expect(text.contains("Bali '27"))
        #expect(text.contains("N4B13L"))
        #expect(text.contains(content.link.absoluteString))
        #expect(text.contains(AppBrand.name))
    }

    @Test func onlyAirDropAndMessagingAreOffered() {
        let excluded = RollInviteContent.excludedActivityTypes
        #expect(excluded.contains(.mail))
        #expect(excluded.contains(.print))
        #expect(!excluded.contains(.airDrop))
        #expect(!excluded.contains(.message))
    }

    // MARK: - Create

    @Test func hostCreatesARoomWithAShareLink() async {
        let vm = makeViewModel()
        vm.draftRollName = "Bali '27"
        vm.draftShotCount = 24

        createLobby(vm, as: host)
        await waitUntil { vm.inviteContent != nil }

        #expect(rooms.created.first?.name == "Bali '27")
        #expect(navigator.path == [.createRollLobby])
        #expect(vm.inviteContent?.link == rooms.shareURL)
        #expect(vm.lobbyParticipants.map(\.userID) == [host.appleUserID])
        #expect(vm.isHost(host))
        // Change 012: the room carries a fresh 256-bit roll key for the encrypted shots.
        #expect(rooms.created.first?.rollKey?.count == 32)
        #expect(vm.activeSession?.rollKey == rooms.created.first?.rollKey)
    }

    @Test func failedInviteLinkShowsAnErrorAndCanRetry() async {
        rooms.createError = .unavailable
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteLinkError != nil }

        #expect(vm.inviteContent == nil)
        #expect(vm.inviteLinkError?.hasPrefix(RollFlowViewModel.inviteLinkFailedMessage) == true)

        rooms.createError = nil
        await vm.createInviteLinkIfNeeded(currentUser: host)

        #expect(vm.inviteLinkError == nil)
        #expect(vm.inviteContent?.link == rooms.shareURL)
        #expect(rooms.created.count == 2)
    }

    @Test func participantNeverCreatesARoom() async {
        hostRoom()
        let vm = makeViewModel()
        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)
        vm.activeSession?.shareURLString = nil

        await vm.createInviteLinkIfNeeded(currentUser: guest)

        #expect(rooms.created.isEmpty)
    }

    // MARK: - Join

    // MARK: - Joining overlay (change 024)

    @Test func joinStatusTextChangesWithTheWait() {
        #expect(RollFlowViewModel.joinStatusText(elapsed: 0) == "Finding the roll…")
        #expect(RollFlowViewModel.joinStatusText(elapsed: 2.9) == "Finding the roll…")
        #expect(RollFlowViewModel.joinStatusText(elapsed: 3) == "Loading the film…")
        #expect(RollFlowViewModel.joinStatusText(elapsed: 8) == "Almost there…")
        #expect(RollFlowViewModel.joinStatusText(elapsed: 60) == "Almost there…")
    }

    @Test func joiningShowsTheOverlayUntilTheLobbyOpens() async {
        hostRoom()
        rooms.joinDelay = .milliseconds(200)
        let vm = makeViewModel()
        navigator.path = [.joinRoll]

        let join = Task { await vm.joinRollWithCode(code: "N4B13L", currentUser: guest) }
        await waitUntil { vm.isJoining }
        #expect(vm.isJoining)
        await join.value

        #expect(!vm.isJoining)
        #expect(navigator.path == [.createRollLobby])
    }

    @Test func cancelLeavesTheRoomWhenTheJoinFinishesLater() async {
        hostRoom()
        rooms.joinDelay = .milliseconds(200)
        let vm = makeViewModel()
        navigator.path = [.joinRoll]

        let join = Task { await vm.joinRollWithCode(code: "N4B13L", currentUser: guest) }
        await waitUntil { vm.isJoining }
        vm.cancelJoin()
        #expect(!vm.isJoining)
        await join.value

        #expect(navigator.path == [.joinRoll])
        #expect(vm.activeSession == nil)
        #expect(rooms.left.map(\.userID) == [guest.appleUserID])
        #expect(rooms.left.first?.owner == "_hostOwner")
    }

    @Test func cancelIgnoresALateFailure() async {
        hostRoom()
        rooms.joinDelay = .milliseconds(200)
        rooms.joinError = .unavailable
        let vm = makeViewModel()
        navigator.path = [.joinRoll]

        let join = Task { await vm.joinRollWithCode(code: "N4B13L", currentUser: guest) }
        await waitUntil { vm.isJoining }
        vm.cancelJoin()
        await join.value

        #expect(vm.joinErrorMessage == nil)
        #expect(rooms.left.isEmpty)
    }

    @Test func cancelledJoinAsTheHostLeavesNothing() async {
        hostRoom()
        rooms.joinDelay = .milliseconds(200)
        let vm = makeViewModel()

        let join = Task { await vm.joinRollWithCode(code: "N4B13L", currentUser: host) }
        await waitUntil { vm.isJoining }
        vm.cancelJoin()
        await join.value

        #expect(rooms.left.isEmpty)
    }

    @Test func aFailedJoinClosesTheOverlayWithTheMessage() async {
        let vm = makeViewModel()
        await vm.joinRollWithCode(code: "ZZZZZZ", currentUser: guest)
        #expect(!vm.isJoining)
        #expect(vm.joinErrorMessage == RollFlowViewModel.joinNotFoundMessage)
    }

    @Test func joinByCodeOpensTheParticipantLobby() async {
        hostRoom()
        let vm = makeViewModel()
        navigator.path = [.joinRoll]

        await vm.joinRollWithCode(code: "n4b13l", currentUser: guest)

        #expect(navigator.path == [.createRollLobby])
        #expect(vm.joinErrorMessage == nil)
        #expect(vm.lobbyParticipants.map(\.userID) == [host.appleUserID, guest.appleUserID])
        #expect(!vm.isHost(guest))
        #expect(vm.activeSession?.ckZoneOwnerName == "_hostOwner")
        #expect(vm.inviteContent != nil, "Link is known, but the invite button is host only")
    }

    @Test func sameICloudAsHostEntersTheRoomWithoutAddingAnyone() async {
        hostRoom()
        let vm = makeViewModel()

        await vm.joinRollWithCode(code: "N4B13L", currentUser: host)

        #expect(navigator.path == [.createRollLobby])
        #expect(vm.lobbyParticipants.map(\.userID) == [host.appleUserID])
        #expect(vm.isHost(host))
        #expect(vm.activeSession?.ckZoneOwnerName == nil, "Own room: private database")
    }

    @Test func joiningTwiceDoesNotAddTheSameUserAgain() async {
        hostRoom()
        let vm = makeViewModel()
        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)
        vm.closeLobby()

        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)

        #expect(vm.lobbyParticipants.map(\.userID) == [host.appleUserID, guest.appleUserID])
    }

    @Test func lateJoinGoesStraightToTheCamera() async {
        hostRoom(status: .live)
        let vm = makeViewModel()

        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)

        #expect(navigator.path == [.captureSession])
    }

    @Test(arguments: [
        (RoomError.notFound, RollFlowViewModel.joinNotFoundMessage),
        (RoomError.ended, RollFlowViewModel.joinEndedMessage),
        (RoomError.unavailable, RollFlowViewModel.joinUnavailableMessage),
    ])
    func joinErrorsShowAMessage(_ error: RoomError, _ message: String) async {
        rooms.joinError = error
        let vm = makeViewModel()

        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)

        #expect(vm.joinErrorMessage == message)
        #expect(navigator.path.isEmpty)
    }

    @Test func joinOfflineShowsTheOfflineMessage() async {
        hostRoom()
        let vm = makeViewModel(online: false)

        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)

        #expect(vm.joinErrorMessage == RollFlowViewModel.joinOfflineMessage)
    }

    // MARK: - Host / participant actions

    @Test func onlyTheHostCanRemoveOthers() async {
        hostRoom()
        let vm = makeViewModel()
        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)
        let hostP = RoomParticipant(userID: host.appleUserID, name: host.name)
        let guestP = RoomParticipant(userID: guest.appleUserID, name: guest.name)

        #expect(vm.canRemove(hostP, currentUser: host) == false, "Host cannot remove themselves")
        #expect(vm.canRemove(guestP, currentUser: host))
        #expect(vm.canRemove(hostP, currentUser: guest) == false, "Participants cannot remove")
    }

    @Test func hostRemovesAParticipant() async {
        hostRoom()
        let vm = makeViewModel()
        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)
        // Same device acting as host for the test: make the host the session's host user.
        let guestP = RoomParticipant(userID: guest.appleUserID, name: guest.name)

        vm.removeParticipant(guestP, currentUser: host)
        await waitUntil { !rooms.removed.isEmpty }

        #expect(vm.lobbyParticipants.map(\.userID) == [host.appleUserID])
        #expect(rooms.removed.first?.userID == guest.appleUserID)
    }

    @Test func participantLeavesTheRoll() async {
        hostRoom()
        let vm = makeViewModel()
        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)

        vm.leaveRoll(currentUser: guest)
        await waitUntil { !rooms.left.isEmpty }

        #expect(rooms.left.first?.userID == guest.appleUserID)
        #expect(rooms.left.first?.owner == "_hostOwner")
        #expect(navigator.path.isEmpty)
        #expect(vm.activeSession == nil)
    }

    @Test func hostDeletesTheRoll() async {
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteContent != nil }
        let code = vm.activeSession?.rollCode

        vm.deleteRoll()
        await waitUntil { !rooms.deleted.isEmpty }

        #expect(rooms.deleted == [code].compactMap { $0 })
        #expect(navigator.path.isEmpty)
        #expect(vm.activeSession == nil)
        #expect((try? context.fetchCount(FetchDescriptor<CaptureSession>())) == 0)
    }

    @Test func closeKeepsTheRoomAndGoesHome() async {
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteContent != nil }

        vm.closeLobby()

        #expect(navigator.path.isEmpty)
        #expect(rooms.deleted.isEmpty)
        #expect((try? context.fetchCount(FetchDescriptor<CaptureSession>())) == 1)
    }

    // MARK: - Lobby refresh

    @Test(arguments: [
        (RoomError.removed, RollFlowViewModel.roomRemovedMessage),
        (RoomError.deleted, RollFlowViewModel.roomDeletedMessage),
    ])
    func removedOrDeletedSendsTheParticipantHome(_ error: RoomError, _ message: String) async {
        hostRoom()
        let store = SessionStore(modelContext: context)
        let vm = makeViewModel(store: store)
        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)

        rooms.fetchError = error
        await vm.refreshLobby()

        // A deleted roll shows the Roll Deleted card instead of a message (change 081).
        if message == RollFlowViewModel.roomDeletedMessage {
            #expect(store.showsRollDeletedCard)
            #expect(vm.roomExitMessage == nil)
        } else {
            #expect(vm.roomExitMessage == message)
            #expect(!store.showsRollDeletedCard)
        }
        #expect(navigator.path.isEmpty)
        #expect(vm.activeSession == nil)
    }

    @Test func participantFollowsTheHostStart() async {
        hostRoom()
        let vm = makeViewModel()
        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)

        rooms.rooms["N4B13L"]?.statusRaw = SessionStatus.live.rawValue
        await vm.refreshLobby()

        #expect(navigator.path == [.createRollLobby, .captureSession])
    }

    @Test func aStartedRollReopenedWaitsForContinueRoll() async {
        hostRoom()
        let vm = makeViewModel()
        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)

        // Reopened from Resume Roll after it started: the lobby stays until Continue Roll (change 081).
        vm.activeSession?.status = .live
        rooms.rooms["N4B13L"]?.statusRaw = SessionStatus.live.rawValue
        await vm.refreshLobby()
        #expect(navigator.path == [.createRollLobby])

        vm.continueRoll()
        #expect(navigator.path == [.createRollLobby, .captureSession])
        #expect(navigator.cameraIntroPhase == .idle)
    }

    // MARK: - Create and edit roll (change 081)

    @Test func nextNeedsANameAndAShotCount() {
        let vm = makeViewModel()
        vm.startCreateRollWizard()
        #expect(vm.draftShotCount == nil)
        #expect(!vm.canProceedFromSetup)

        vm.draftRollName = "   "
        vm.draftShotCount = 48
        #expect(!vm.canProceedFromSetup)
        vm.proceedToFilterStep()
        #expect(navigator.path == [.createRollSetup])

        vm.draftRollName = "Bali '27"
        #expect(vm.canProceedFromSetup)
        vm.proceedToFilterStep()
        #expect(navigator.path == [.createRollSetup, .createRollFilter])
    }

    @Test func guidanceFollowsTheShotCount() {
        #expect(RollFlowViewModel.friendsGuide(for: nil) == nil)
        #expect(RollFlowViewModel.friendsGuide(for: 24) == "suitable for 2-3 friends")
        #expect(RollFlowViewModel.friendsGuide(for: 36) == "suitable for 4-6 friends")
        #expect(RollFlowViewModel.friendsGuide(for: 48) == "suitable for 7-8 friends")
        #expect(RollFlowViewModel.friendsGuide(for: 72) == "suitable for 8+ friends")
    }

    @Test func editRollSavesNameShotsAndFilter() async throws {
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteContent != nil }
        let session = try #require(vm.activeSession)
        let lobbyPath = navigator.path

        vm.editRoom()
        #expect(vm.isEditingRoll)
        #expect(vm.draftRollName == session.name)
        #expect(vm.draftShotCount == session.rollSize)
        #expect(navigator.path == lobbyPath + [.editRollSetup])

        // ‹ leaves without saving.
        vm.draftRollName = "Nope"
        vm.cancelEditRoll()
        #expect(session.name == "Roll")
        #expect(navigator.path == lobbyPath)

        vm.editRoom()
        vm.draftRollName = "Bali '27"
        vm.draftShotCount = 72
        vm.draftFilter = .cinematicBW400
        vm.proceedToFilterStep()
        vm.saveRollEdits()
        // Let the CloudKit publish read the roll before the test's store goes away.
        try await Task.sleep(for: .milliseconds(100))
        #expect(session.name == "Bali '27")
        #expect(session.rollSize == 72)
        #expect(session.filter == .cinematicBW400)
        #expect(!vm.isEditingRoll)
        #expect(navigator.path == lobbyPath)
    }

    @Test func systemBackFromEditRollLeavesEditMode() async throws {
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteContent != nil }
        let session = try #require(vm.activeSession)

        vm.editRoom()
        vm.draftRollName = "Nope"
        // The system back button pops to the lobby without calling cancelEditRoll (change 122).
        navigator.path.removeLast()
        vm.lobbyDidAppear(currentUser: host)
        #expect(!vm.isEditingRoll)
        #expect(session.name == "Roll")
        #expect(vm.draftRollName.isEmpty)
    }

    @Test func aStartedRollCantBeEdited() async throws {
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteContent != nil }
        let session = try #require(vm.activeSession)
        session.status = .live
        let path = navigator.path

        vm.editRoom()
        #expect(!vm.isEditingRoll)
        #expect(navigator.path == path)
    }

    @Test func deletingTheRollShowsRollDeleted() async {
        let store = SessionStore(modelContext: context)
        let vm = makeViewModel(store: store)
        createLobby(vm, as: host)
        await waitUntil { vm.inviteContent != nil }

        vm.deleteRoll()
        #expect(store.showsRollDeletedCard)
    }

    @Test func newParticipantsAppearOnRefresh() async {
        hostRoom()
        let vm = makeViewModel()
        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)

        rooms.rooms["N4B13L"]?.participants.append(RoomParticipant(userID: "f-3", name: "Fikri"))
        await vm.refreshLobby()

        #expect(vm.lobbyParticipants.map(\.name) == ["Nabiel", "Brian Chang", "Fikri"])
        #expect(vm.lobbyJoinedCount == 3)
    }

    // MARK: - Camera UI Update (Change 041, 086)

    @Test func prepareCameraReturnSetsNavigatorTransitionPhase() {
        let vm = makeViewModel()
        vm.prepareCameraReturn(angle: 90.0)

        #expect(navigator.cameraReturnPhase == .zoomedIn)
        #expect(navigator.cameraReturnAngle == 90.0)
        #expect(navigator.isTabBarHidden)
    }

    @Test func returnToHomepagePopsToRootAndResetsOrientation() {
        let vm = makeViewModel()
        OrientationLock.set(.landscape)
        navigator.path = [.captureSession]
        vm.isInviteSheetPresented = true

        vm.returnToHomepage()

        #expect(OrientationLock.mask == OrientationLock.defaultMask())
        #expect(navigator.path.isEmpty)
        #expect(!vm.isInviteSheetPresented)
    }

    @Test func closeLobbyResetsOrientationLockToPortrait() {
        let vm = makeViewModel()
        OrientationLock.set(.landscape)
        navigator.path = [.createRollLobby]

        vm.closeLobby()

        #expect(OrientationLock.mask == OrientationLock.defaultMask())
        #expect(navigator.path.isEmpty)
    }

    // MARK: - Join code entry and messages (change 019)

    @Test func joinCodeTypingBackspaceEditAndPaste() {
        let vm = makeViewModel()
        vm.updateJoinCode("n4b")
        #expect(vm.joinCode == "N4B")
        vm.updateJoinCode("N4")            // backspace
        #expect(vm.joinCode == "N4")
        vm.updateJoinCode("N4X13L")        // fix the typo and finish
        #expect(vm.joinCode == "N4X13L")
        #expect(vm.joinCodeCharacter(at: 2) == "X")
        #expect(vm.joinCodeCharacter(at: 5) == "L")
        vm.updateJoinCode("")
        vm.updateJoinCode(" n4-b1 3l99 ")  // paste: filtered, uppercased, max 6
        #expect(vm.joinCode == "N4B13L")
        vm.updateJoinCode("ÄB")            // letters / numbers only (ASCII)
        #expect(vm.joinCode == "B")
    }

    @Test func shortCodeShowsAMessageWithoutCallingTheServer() async {
        rooms.joinError = .unavailable
        let vm = makeViewModel()
        vm.updateJoinCode("N4B")

        await vm.submitJoinCode(currentUser: guest)

        #expect(vm.joinErrorMessage == RollFlowViewModel.joinIncompleteCodeMessage)
        #expect(navigator.path.isEmpty)
    }

    @Test func editingTheCodeClearsTheMessage() async {
        let vm = makeViewModel()
        vm.updateJoinCode("N4")
        await vm.submitJoinCode(currentUser: guest)
        #expect(vm.joinErrorMessage != nil)
        vm.updateJoinCode("N4B")
        #expect(vm.joinErrorMessage == nil)
    }

    @Test func serverErrorsShowOnlyTheShortMessage() async {
        rooms.joinError = .notFound
        rooms.lastErrorDescription = "own room: <CKError 0x1 \"Zone Not Found\" (26/2036)>"
        let vm = makeViewModel()
        vm.updateJoinCode("GCDFYH")

        await vm.submitJoinCode(currentUser: guest)

        #expect(vm.joinErrorMessage == RollFlowViewModel.joinNotFoundMessage)
        #expect(vm.joinErrorMessage?.contains("CKError") == false)
    }

    @Test func failedInviteLinkMessageHasNoTechnicalDetail() async {
        rooms.createError = .unavailable
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteLinkError != nil }
        #expect(vm.inviteLinkError == RollFlowViewModel.inviteLinkFailedMessage)
    }

    // MARK: - Lobby menu and invites (change 019)

    @Test func inviteTileIsForTheHostOnly() async {
        hostRoom()
        let vm = makeViewModel()
        await vm.joinRollWithCode(code: "N4B13L", currentUser: guest)
        #expect(vm.lobbyTiles(currentUser: guest).contains(.invite) == false)
        #expect(vm.lobbyTiles(currentUser: host).last == .invite)
        #expect(vm.lobbyTiles(currentUser: host).count == vm.lobbyParticipants.count + 1)
    }

    @Test func inviteFriendsOpensOnTheOptionsPage() {
        let vm = makeViewModel()
        vm.showRoomCode()
        vm.presentInviteFriends()
        #expect(vm.isInviteSheetPresented)
        #expect(vm.invitePage == .options)
        vm.showRoomCode()
        #expect(vm.invitePage == .code)
        vm.showInviteOptions()
        #expect(vm.invitePage == .options)
    }

    @Test func shareRoomOpensTheShareSheetOnceTheLinkExists() async {
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteContent != nil }

        await vm.shareRoom(currentUser: host)
        #expect(vm.isShareSheetPresented)

        await vm.inviteViaAirDrop(currentUser: host)
        #expect(vm.isAirDropSheetPresented)
    }

    @Test func shareRoomWithoutALinkShowsAnError() async {
        rooms.createError = .unavailable
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteLinkError != nil }

        await vm.shareRoom(currentUser: host)

        #expect(!vm.isShareSheetPresented)
        #expect(vm.shareErrorMessage == RollFlowViewModel.inviteLinkFailedMessage)
    }

    @Test func deleteRoomAsksBeforeDeleting() async {
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteContent != nil }
        let code = vm.roomCode

        vm.requestDeleteRoom()
        #expect(vm.isDeleteRoomConfirmationPresented)
        #expect(rooms.deleted.isEmpty)

        vm.deleteRoll()
        await waitUntil { !rooms.deleted.isEmpty }
        #expect(rooms.deleted == [code])
    }

    @Test func airDropInviteHidesEverythingButAirDrop() {
        let excluded = RollInviteContent.airDropOnlyExcludedActivityTypes
        #expect(!excluded.contains(.airDrop))
        #expect(excluded.contains(.message))
        #expect(excluded.contains(.mail))
        #expect(excluded.contains(UIActivity.ActivityType("net.whatsapp.WhatsApp.ShareExtension")))
    }

    // MARK: - Avatars

    @Test(arguments: [("Sanny", "S"), ("Brian Chang", "BC"), ("fikri ahmad rizal", "FA"), ("", "?")])
    func initials(_ name: String, _ expected: String) {
        #expect(RollFlowViewModel.initials(for: name) == expected)
    }

    @Test func hostAndGuestCarryAvatarThumbnailsWhenCreatingAndJoining() async {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        let avatarBytes = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }.pngData()!

        host.avatarData = avatarBytes
        guest.avatarData = avatarBytes

        let hostVM = makeViewModel()
        createLobby(hostVM, as: host)
        await waitUntil { hostVM.inviteContent != nil }

        #expect(hostVM.lobbyParticipants.first?.avatarData != nil)
        #expect(rooms.created.first?.host.avatarData != nil)

        let guestVM = makeViewModel()
        await guestVM.joinRollWithCode(code: hostVM.roomCode, currentUser: guest)

        #expect(guestVM.lobbyParticipants.count == 2)
        #expect(guestVM.lobbyParticipants.allSatisfy { $0.avatarData != nil })
    }

    @Test func reenteringLobbySyncsUpdatedProfileNameAndAvatar() async {
        let vm = makeViewModel()
        createLobby(vm, as: host)
        await waitUntil { vm.inviteContent != nil }
        #expect(vm.lobbyParticipants.first?.name == "Nabiel")
        #expect(vm.lobbyParticipants.first?.avatarData == nil)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        let newAvatar = renderer.image { ctx in
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }.pngData()!
        host.name = "Nabiel Updated"
        host.avatarData = newAvatar

        vm.lobbyDidAppear(currentUser: host)
        await waitUntil { !rooms.updated.isEmpty }
        vm.lobbyDidDisappear()

        #expect(rooms.updated.last?.user.name == "Nabiel Updated")
        #expect(rooms.updated.last?.user.avatarData != nil)
        #expect(vm.lobbyParticipants.first?.name == "Nabiel Updated")
        #expect(vm.lobbyParticipants.first?.avatarData != nil)
    }
}
