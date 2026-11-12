import CloudKit
import Foundation
import SwiftData
import Testing
@testable import ScrapIt

@MainActor
private final class MockWorkbenchRoomService: RollRoomServicing {
    var lastErrorDescription: String?
    var fetchResults: [String: Result<RoomSnapshot, Error>] = [:]
    var handoverCalls: [(code: String, zoneOwnerName: String?, leavingUserID: String, nextHostUserID: String)] = []
    var leaveCalls: [(code: String, zoneOwnerName: String, userID: String)] = []
    var deleteCalls: [String] = []

    func createRoom(_ draft: RoomDraft) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func joinRoom(code: String, as user: RoomParticipant) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func acceptShare(_ metadata: CKShare.Metadata, as user: RoomParticipant) async throws -> RoomSnapshot { throw RoomError.unavailable }

    func fetchRoom(code: String, zoneOwnerName: String?) async throws -> RoomSnapshot {
        switch fetchResults[code] {
        case .success(let snapshot):
            return snapshot
        case .failure(let error):
            throw error
        case nil:
            throw RoomError.notFound
        }
    }

    func removeParticipant(userID: String, fromRoom code: String) async throws {}

    func leaveRoom(code: String, zoneOwnerName: String, userID: String) async throws {
        leaveCalls.append((code, zoneOwnerName, userID))
    }

    func leaveAsHostHandover(
        code: String,
        zoneOwnerName: String?,
        leavingUserID: String,
        nextHostUserID: String
    ) async throws {
        handoverCalls.append((code, zoneOwnerName, leavingUserID, nextHostUserID))
    }

    func deleteRoom(code: String) async throws {
        deleteCalls.append(code)
    }

    func listRooms() async throws -> [RoomSnapshot] { [] }
    func downloadShotPayload(recordName: String) async throws -> Data { throw RoomError.unavailable }
}

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
        currentUser: UserProfile? = nil,
        roomService: MockWorkbenchRoomService? = nil,
        defaults: UserDefaults? = nil,
        delay: Duration = .milliseconds(10)
    ) -> (WorkbenchViewModel, AppRouter, SessionStore) {
        let resolvedRouter = router ?? AppRouter()
        let store = SessionStore(modelContext: context)
        let deleted = DeletedScrapbookList(defaults: defaults ?? makeDefaults().0)
        let vm = WorkbenchViewModel(
            modelContext: context,
            navigator: resolvedRouter,
            sessionStore: store,
            currentUser: currentUser,
            roomService: roomService,
            deletedScrapbooks: deleted,
            toolboxTransitionDelay: delay,
            rollsTransitionDelay: delay
        )
        return (vm, resolvedRouter, store)
    }

    @Test func activateToolboxHidesTabBarAndPushesCollection() async throws {
        let (vm, router, _) = makeViewModel(delay: .milliseconds(20))

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

    @Test func activateRollsHidesTabBarPushesCollectionAndCancelsCleanly() async throws {
        let (vm, router, _) = makeViewModel(delay: .milliseconds(40))

        vm.activateRolls()
        #expect(vm.isRollsActive)
        #expect(router.isTabBarHidden)

        // Mutually exclusive with camera and toolbox
        vm.toggleCamera()
        vm.activateToolbox()
        #expect(!vm.isCameraActive)
        #expect(!vm.isToolboxActive)

        for _ in 0..<100 where vm.isRollsActive {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isRollsActive)
        #expect(!router.isTabBarHidden)
        #expect(router.path == [.deskCollection(.rolls)])

        // Cancellation aborts navigation
        router.popToRoot()
        vm.activateRolls()
        vm.cancelRollsTransition()
        #expect(!vm.isRollsActive)
        try await Task.sleep(for: .milliseconds(80))
        #expect(router.path.isEmpty)
    }

    @Test func cameraAndToolboxMutuallyExcludeAndCancelStopsNavigation() async throws {
        let (vm, router, _) = makeViewModel(delay: .milliseconds(80))

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
        let (vm, _, _) = makeViewModel()
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
        let (vm, _, _) = makeViewModel()
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

        let (vm, router, _) = makeViewModel(defaults: defaults)
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

    @Test func activeRollsRefreshOpenAndHostSafeLeaveHandover() async throws {
        let user = UserProfile(appleUserID: "me-1", name: "Lepin")
        context.insert(user)
        let roomService = MockWorkbenchRoomService()
        let (vm, router, store) = makeViewModel(currentUser: user, roomService: roomService)

        let waiting = CaptureSession(
            name: "Waiting Roll",
            rollCode: "WAIT01",
            ckRecordName: "RollSession",
            hostUserID: "me-1",
            participantIDs: ["me-1", "friend-2"],
            participantNames: ["Lepin", "Biel"],
            rollSize: 24,
            slotsUsed: 0,
            filter: .cinematicBW400,
            status: .waiting,
            startTime: Date(timeIntervalSince1970: 1_795_000_000)
        )
        let live = CaptureSession(
            name: "Live Roll",
            rollCode: "LIVE02",
            ckRecordName: "RollSession",
            hostUserID: "friend-2",
            participantIDs: ["me-1", "friend-2", "friend-3"],
            participantNames: ["Lepin", "Biel", "Sanny"],
            rollSize: 36,
            slotsUsed: 12,
            filter: .colorPrint200,
            status: .live,
            startTime: Date(timeIntervalSince1970: 1_795_100_000)
        )
        live.ckZoneOwnerName = "owner-zone"
        let ended = CaptureSession(
            name: "Finished Roll",
            rollCode: "DONE03",
            hostUserID: "me-1",
            participantIDs: ["me-1"],
            participantNames: ["Lepin"],
            rollSize: 24,
            slotsUsed: 24,
            filter: .colorPrint200,
            status: .ended
        )
        context.insert(waiting)
        context.insert(live)
        context.insert(ended)
        try context.save()

        #expect(vm.activeRolls.map(\.rollCode) == ["LIVE02", "WAIT01"])
        #expect(vm.canisterAsset(for: .cinematicBW400) == "FilterCanisterBW")
        #expect(vm.canisterAsset(for: .colorPrint200) == "FilterCanisterColor")

        // Refresh syncs remote host change & slot counts
        roomService.fetchResults["WAIT01"] = .success(RoomSnapshot(
            sessionID: waiting.id,
            rollCode: "WAIT01",
            name: "Waiting Roll",
            hostUserID: "friend-2",
            rollSize: 24,
            slotsUsed: 3,
            filterRaw: RollFilter.cinematicBW400.rawValue,
            statusRaw: SessionStatus.waiting.rawValue,
            participants: [
                RoomParticipant(userID: "me-1", name: "Lepin"),
                RoomParticipant(userID: "friend-2", name: "Biel"),
            ],
            shareURL: nil,
            zoneOwnerName: nil,
            rollKey: nil
        ))
        // Live roll ended remotely while user was away
        roomService.fetchResults["LIVE02"] = .success(RoomSnapshot(
            sessionID: live.id,
            rollCode: "LIVE02",
            name: "Live Roll",
            hostUserID: "friend-2",
            rollSize: 36,
            slotsUsed: 36,
            filterRaw: RollFilter.colorPrint200.rawValue,
            statusRaw: SessionStatus.ended.rawValue,
            participants: [
                RoomParticipant(userID: "me-1", name: "Lepin"),
                RoomParticipant(userID: "friend-2", name: "Biel"),
            ],
            shareURL: nil,
            zoneOwnerName: "owner-zone",
            rollKey: nil
        ))
        await vm.refreshActiveRolls()
        #expect(waiting.hostUserID == "friend-2")
        #expect(waiting.slotsUsed == 3)
        // Un-finalized remotely ended roll remains visible until tapped so Reveal opens
        #expect(vm.activeRolls.contains(where: { $0.id == live.id }))

        // Tapping waiting roll opens lobby
        await vm.openRoll(waiting)
        #expect(store.activeSession?.id == waiting.id)
        #expect(router.path.last == .createRollLobby)

        // Tapping remotely ended roll opens Roll Reveal and marks ended
        router.popToRoot()
        await vm.openRoll(live)
        guard case .rollReveal = router.path.last else {
            Issue.record("Expected rollReveal route when opening remotely ended roll")
            return
        }
        #expect(live.status == .ended)

        // Tapping local live offline roll falls back to captureSession
        let localLive = CaptureSession(
            name: "Local Shoot",
            rollCode: "LOCL04",
            hostUserID: "me-1",
            participantIDs: ["me-1", "friend-9"],
            participantNames: ["Lepin", "Alex"],
            rollSize: 24,
            slotsUsed: 4,
            filter: .cinematicBW400,
            status: .live
        )
        localLive.ckRecordName = "RollSession"
        roomService.fetchResults["LOCL04"] = .failure(RoomError.offline)
        context.insert(localLive)
        try context.save()

        router.popToRoot()
        await vm.openRoll(localLive)
        #expect(router.path.last == .captureSession)

        // Host leaving roll with remaining participant hands over host without deleting room
        vm.requestLeaveRoll(localLive)
        vm.confirmLeaveRoll()
        try await Task.sleep(for: .milliseconds(30))
        #expect(roomService.handoverCalls.count == 1)
        #expect(roomService.handoverCalls.first?.leavingUserID == "me-1")
        #expect(roomService.handoverCalls.first?.nextHostUserID == "friend-9")
        #expect(roomService.deleteCalls.isEmpty)
        #expect(!vm.activeRolls.contains(where: { $0.id == localLive.id }))
    }
}
