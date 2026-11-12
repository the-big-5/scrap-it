import Foundation
import Observation
import SwiftData

@Observable
final class WorkbenchViewModel {
    private static let folderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private let modelContext: ModelContext
    @ObservationIgnored private weak var navigator: (any Navigator)?
    private let sessionStore: SessionStore
    private let currentUser: UserProfile?
    @ObservationIgnored private let roomService: (any RollRoomServicing)?
    private let deletedScrapbooks: DeletedScrapbookList
    private let toolboxTransitionDelay: Duration
    private let rollsTransitionDelay: Duration

    private var scrapbooksRevision: Int = 0
    private var rollsRevision: Int = 0
    @ObservationIgnored private var toolboxTask: Task<Void, Never>?
    @ObservationIgnored private var rollsTask: Task<Void, Never>?

    var isCameraActive: Bool = false {
        didSet {
            syncTabBarVisibility()
        }
    }

    var isToolboxActive: Bool = false {
        didSet {
            syncTabBarVisibility()
        }
    }

    var isRollsActive: Bool = false {
        didSet {
            syncTabBarVisibility()
        }
    }

    var scrapbookPendingRemoval: Scrapbook?
    var rollPendingLeave: CaptureSession?
    var rollPendingDelete: CaptureSession?
    var rollNoticeMessage: String?
    var isOpeningRoll: Bool = false

    /// Return transition phase when navigating back from camera (change 086).
    var cameraReturnPhase: CameraReturnPhase {
        navigator?.cameraReturnPhase ?? .idle
    }

    var cameraReturnAngle: Double {
        navigator?.cameraReturnAngle ?? 0.0
    }

    func animateCameraReturnToIdle() {
        navigator?.animateCameraReturnToIdle()
    }

    func finishCameraReturn() {
        navigator?.finishCameraReturn()
    }

    init(
        modelContext: ModelContext,
        navigator: (any Navigator)? = nil,
        sessionStore: SessionStore,
        currentUser: UserProfile? = nil,
        roomService: (any RollRoomServicing)? = nil,
        deletedScrapbooks: DeletedScrapbookList = .standard,
        toolboxTransitionDelay: Duration = .milliseconds(900),
        rollsTransitionDelay: Duration = .milliseconds(850)
    ) {
        self.modelContext = modelContext
        self.navigator = navigator
        self.sessionStore = sessionStore
        self.currentUser = currentUser
        self.roomService = roomService
        self.deletedScrapbooks = deletedScrapbooks
        self.toolboxTransitionDelay = toolboxTransitionDelay
        self.rollsTransitionDelay = rollsTransitionDelay
    }

    private var resolvedRoomService: any RollRoomServicing {
        roomService ?? CloudKitRollRoomService()
    }

    var scrapbooks: [Scrapbook] {
        _ = scrapbooksRevision
        let descriptor = FetchDescriptor<Scrapbook>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var activeRolls: [CaptureSession] {
        _ = rollsRevision
        let descriptor = FetchDescriptor<CaptureSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return sessions.filter { $0.status != .ended }
    }

    func reloadScrapbooks() {
        scrapbooksRevision &+= 1
    }

    func reloadRolls() {
        rollsRevision &+= 1
    }

    func toggleCamera() {
        guard !isToolboxActive, !isRollsActive else { return }
        isCameraActive.toggle()
    }

    func dismissCamera() {
        isCameraActive = false
    }

    func activateToolbox() {
        guard !isCameraActive, !isToolboxActive, !isRollsActive else { return }
        isToolboxActive = true
        toolboxTask?.cancel()
        toolboxTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if self.toolboxTransitionDelay > .zero {
                    try await Task.sleep(for: self.toolboxTransitionDelay)
                }
                guard !Task.isCancelled, self.isToolboxActive else { return }
                self.isToolboxActive = false
                self.toolboxTask = nil
                self.navigator?.push(.deskCollection(.scrapbooks))
            } catch {
                // Cancelled before navigation completed.
            }
        }
    }

    func cancelToolboxTransition() {
        toolboxTask?.cancel()
        toolboxTask = nil
        if isToolboxActive {
            isToolboxActive = false
        }
    }

    func activateRolls() {
        guard !isCameraActive, !isToolboxActive, !isRollsActive else { return }
        isRollsActive = true
        rollsTask?.cancel()
        rollsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if self.rollsTransitionDelay > .zero {
                    try await Task.sleep(for: self.rollsTransitionDelay)
                }
                guard !Task.isCancelled, self.isRollsActive else { return }
                self.isRollsActive = false
                self.rollsTask = nil
                self.navigator?.push(.deskCollection(.rolls))
            } catch {
                // Cancelled before navigation completed.
            }
        }
    }

    func cancelRollsTransition() {
        rollsTask?.cancel()
        rollsTask = nil
        if isRollsActive {
            isRollsActive = false
        }
    }

    func startCreateRoll() {
        isCameraActive = false
        navigator?.setStack([.createRollSetup])
    }

    func startJoinRoll() {
        isCameraActive = false
        navigator?.setStack([.joinRoll])
    }

    func startCreateRollFromCollection() {
        navigator?.setStack([.createRollSetup])
    }

    func closeCollection() {
        if let navigator, !navigator.path.isEmpty {
            navigator.path.removeLast()
        }
    }

    func openTutorial() {
        // Stub for upcoming tutorial flow
    }

    func openScrapbook(_ scrapbook: Scrapbook) {
        sessionStore.activeScrapbook = scrapbook
        navigator?.push(.scrapbook(scrapbook.id))
    }

    func openLatestScrapbook() {
        if let latest = scrapbooks.first {
            openScrapbook(latest)
        }
    }

    // MARK: - Resume Editing Collection Helpers

    func folderTheme(at index: Int) -> FolderCardTheme {
        let themes = FolderCardTheme.allCases
        return themes[index % themes.count]
    }

    func formattedDate(for scrapbook: Scrapbook) -> String {
        Self.folderDateFormatter.string(from: scrapbook.createdDate)
    }

    func previewPhotos(for scrapbook: Scrapbook) -> [FolderPreviewPhoto] {
        let photos = (scrapbook.photos ?? []).sorted {
            if $0.timestamp != $1.timestamp {
                return $0.timestamp < $1.timestamp
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        guard !photos.isEmpty else { return [] }

        var rng = SeededUUIDGenerator(uuid: scrapbook.id)
        let maxCount = min(4, photos.count)
        let count = Int.random(in: 1...maxCount, using: &rng)
        return photos.shuffled(using: &rng)
            .prefix(count)
            .map { FolderPreviewPhoto(id: $0.id, data: $0.imageData) }
    }

    func requestRemoveFromDevice(_ scrapbook: Scrapbook) {
        scrapbookPendingRemoval = scrapbook
    }

    func confirmRemoveFromDevice() {
        guard let scrapbook = scrapbookPendingRemoval else { return }
        scrapbookPendingRemoval = nil

        ScrapbookLocalDeletionService.deleteLocalCopy(
            of: scrapbook,
            modelContext: modelContext,
            deletedScrapbooks: deletedScrapbooks
        )
        reloadScrapbooks()
    }

    // MARK: - Resume Roll Collection Helpers (Change 106)

    func formattedRollDate(for session: CaptureSession) -> String {
        Self.folderDateFormatter.string(from: session.startTime)
    }

    func canisterAsset(for filter: RollFilter) -> String {
        switch filter {
        case .cinematicBW400: "FilterCanisterBW"
        case .colorPrint200: "FilterCanisterColor"
        }
    }

    func joinedCount(for session: CaptureSession) -> Int {
        max(1, session.participantIDs.count)
    }

    func isHost(of session: CaptureSession) -> Bool {
        guard let currentUserID = currentUser?.appleUserID else { return false }
        return session.hostUserID == currentUserID
    }

    /// Silently refreshes all local non-ended rolls from CloudKit (`fetchRoom`), updating host, participants, and shot counts.
    func refreshActiveRolls() async {
        let sessions = activeRolls
        let service = resolvedRoomService
        var mutated = false

        for session in sessions {
            guard session.modelContext != nil else { continue }

            // Clean up any stale session already finalized into a local scrapbook.
            if existingScrapbook(forSessionID: session.id) != nil {
                session.status = .ended
                if session.endTime == nil { session.endTime = .now }
                mutated = true
                continue
            }

            guard session.ckRecordName != nil else { continue }
            do {
                let snapshot = try await service.fetchRoom(
                    code: session.rollCode,
                    zoneOwnerName: session.ckZoneOwnerName
                )
                guard session.modelContext != nil else { continue }
                if let myID = currentUser?.appleUserID,
                   !snapshot.participants.contains(where: { $0.userID == myID }) {
                    deleteLocalSession(session)
                    mutated = true
                    continue
                }
                // Keep un-finalized remotely ended rolls selectable so tapping opens Roll Reveal (3A).
                apply(snapshot, to: session, preserveNonEndedForReveal: true)
                mutated = true
            } catch RoomError.removed, RoomError.deleted {
                deleteLocalSession(session)
                mutated = true
            } catch {
                // Offline or transient CloudKit error: keep cached local state.
            }
        }

        if mutated {
            try? modelContext.save()
            reloadRolls()
        }
    }

    func openRoll(_ session: CaptureSession) async {
        guard !isOpeningRoll, session.modelContext != nil else { return }
        isOpeningRoll = true
        defer { isOpeningRoll = false }

        let service = resolvedRoomService
        var resolvedRemoteEnded = session.status == .ended

        if session.ckRecordName != nil {
            do {
                let snapshot = try await service.fetchRoom(
                    code: session.rollCode,
                    zoneOwnerName: session.ckZoneOwnerName
                )
                guard session.modelContext != nil else { return }
                if let myID = currentUser?.appleUserID,
                   !snapshot.participants.contains(where: { $0.userID == myID }) {
                    deleteLocalSession(session)
                    try? modelContext.save()
                    reloadRolls()
                    rollNoticeMessage = RollFlowViewModel.roomRemovedMessage
                    return
                }
                apply(snapshot, to: session, preserveNonEndedForReveal: false)
                try? modelContext.save()
                resolvedRemoteEnded = (snapshot.statusRaw == SessionStatus.ended.rawValue)
            } catch RoomError.deleted {
                deleteLocalSession(session)
                try? modelContext.save()
                reloadRolls()
                sessionStore.showsRollDeletedCard = true
                return
            } catch RoomError.removed {
                deleteLocalSession(session)
                try? modelContext.save()
                reloadRolls()
                rollNoticeMessage = RollFlowViewModel.roomRemovedMessage
                return
            } catch {
                // Offline fallback: resume using locally saved roll state.
            }
        }

        if resolvedRemoteEnded || session.status == .ended {
            handleRemotelyEndedRoll(session, service: service)
            return
        }

        sessionStore.activeSession = session
        switch session.status {
        case .waiting, .live:
            // A started roll opens its lobby too, with Continue Roll (change 081).
            navigator?.push(.createRollLobby)
        case .ended:
            handleRemotelyEndedRoll(session, service: service)
        }
    }

    func requestLeaveRoll(_ session: CaptureSession) {
        rollPendingLeave = session
    }

    func confirmLeaveRoll() {
        guard let session = rollPendingLeave else { return }
        rollPendingLeave = nil

        let code = session.rollCode
        let owner = session.ckZoneOwnerName
        let isCloudRoom = session.ckRecordName != nil
        let myID = currentUser?.appleUserID ?? ""
        let remainingParticipants = session.participantIDs.filter { $0 != myID }
        let wasHost = isHost(of: session)

        deleteLocalSession(session)
        try? modelContext.save()
        reloadRolls()

        guard isCloudRoom else { return }
        let service = resolvedRoomService

        if wasHost {
            if let nextHostID = remainingParticipants.first {
                Task {
                    try? await service.leaveAsHostHandover(
                        code: code,
                        zoneOwnerName: owner,
                        leavingUserID: myID,
                        nextHostUserID: nextHostID
                    )
                }
            } else {
                Task { try? await service.deleteRoom(code: code) }
            }
        } else if let owner, !myID.isEmpty {
            Task { try? await service.leaveRoom(code: code, zoneOwnerName: owner, userID: myID) }
        }
    }

    func requestDeleteRoll(_ session: CaptureSession) {
        guard isHost(of: session) else { return }
        rollPendingDelete = session
    }

    func confirmDeleteRoll() {
        guard let session = rollPendingDelete else { return }
        rollPendingDelete = nil

        let code = session.rollCode
        let isCloudRoom = session.ckRecordName != nil
        deleteLocalSession(session)
        try? modelContext.save()
        reloadRolls()
        sessionStore.showsRollDeletedCard = true

        if isCloudRoom {
            let service = resolvedRoomService
            Task { try? await service.deleteRoom(code: code) }
        }
    }

    private func handleRemotelyEndedRoll(_ session: CaptureSession, service: any RollRoomServicing) {
        if existingScrapbook(forSessionID: session.id) != nil {
            session.status = .ended
            if session.endTime == nil { session.endTime = .now }
            try? modelContext.save()
            reloadRolls()
            rollNoticeMessage = "This roll has ended. Find its scrapbook in Resume Editing or Library."
            return
        }

        sessionStore.activeSession = session
        guard let scrapbook = sessionStore.finalizeActiveSession() else {
            reloadRolls()
            return
        }
        let archiveSync = ScrapbookArchiveSync(
            modelContext: modelContext,
            roomService: service,
            deletedScrapbooks: deletedScrapbooks
        )
        Task { await archiveSync.syncRoom(for: session) }
        reloadScrapbooks()
        reloadRolls()
        navigator?.push(.rollReveal(scrapbook.id))
    }

    private func apply(
        _ snapshot: RoomSnapshot,
        to session: CaptureSession,
        preserveNonEndedForReveal: Bool
    ) {
        session.name = snapshot.name
        session.hostUserID = snapshot.hostUserID
        session.rollSize = snapshot.rollSize
        session.slotsUsed = max(session.slotsUsed, snapshot.slotsUsed)
        session.filterRaw = snapshot.filterRaw
        if !(preserveNonEndedForReveal && snapshot.statusRaw == SessionStatus.ended.rawValue) {
            session.statusRaw = snapshot.statusRaw
        }
        if let endTime = snapshot.endTime {
            session.endTime = endTime
        }
        session.participantIDs = snapshot.participants.map(\.userID)
        session.participantNames = snapshot.participants.map(\.name)
        session.ckRecordName = RollRoomLocation.sessionRecordName
        session.ckZoneOwnerName = snapshot.zoneOwnerName
        if let link = snapshot.shareURL {
            session.shareURLString = link.absoluteString
        }
        if let key = snapshot.rollKey {
            session.rollKey = key
        }
    }

    private func existingScrapbook(forSessionID sessionID: UUID) -> Scrapbook? {
        let descriptor = FetchDescriptor<Scrapbook>(
            predicate: #Predicate { $0.sourceSessionID == sessionID }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func deleteLocalSession(_ session: CaptureSession) {
        if sessionStore.activeSession === session {
            sessionStore.activeSession = nil
        }
        modelContext.delete(session)
    }

    private func syncTabBarVisibility() {
        navigator?.isTabBarHidden = isCameraActive || isToolboxActive || isRollsActive
    }
}

private struct SeededUUIDGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(uuid: UUID) {
        let b = uuid.uuid
        let hi = UInt64(b.0)
            | (UInt64(b.1) << 8)
            | (UInt64(b.2) << 16)
            | (UInt64(b.3) << 24)
            | (UInt64(b.4) << 32)
            | (UInt64(b.5) << 40)
            | (UInt64(b.6) << 48)
            | (UInt64(b.7) << 56)
        let lo = UInt64(b.8)
            | (UInt64(b.9) << 8)
            | (UInt64(b.10) << 16)
            | (UInt64(b.11) << 24)
            | (UInt64(b.12) << 32)
            | (UInt64(b.13) << 40)
            | (UInt64(b.14) << 48)
            | (UInt64(b.15) << 56)
        let mixed = hi ^ (lo &* 0x9E3779B97F4A7C15)
        self.state = mixed == 0 ? 0x9E3779B97F4A7C15 : mixed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
