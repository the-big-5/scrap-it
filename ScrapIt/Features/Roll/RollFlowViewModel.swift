import CoreGraphics
import CloudKit
import Foundation
import Observation
import OSLog
import SwiftData
import SwiftUI

/// Single ViewModel for the Roll feature: create, join, capture and end a roll.
/// A cell in the lobby grid: a person, or the host's "+" invite tile (change 019).
enum LobbyTile: Identifiable, Equatable {
    case participant(RoomParticipant)
    case invite

    var id: String {
        switch self {
        case .participant(let participant): participant.userID
        case .invite: "invite-tile"
        }
    }
}

/// Pages of the host's Invite Friends sheet (change 019).
enum InvitePage: Equatable {
    case options
    case code
}

@Observable
final class RollFlowViewModel {
    static let availableShotCounts = [24, 36, 48, 72]

    // Create Roll draft fields
    var draftRollName: String = ""
    var draftShotCount: Int = 36
    var draftFilter: RollFilter = .colorPrint200
    /// Sample photos per filter, rendered with the camera pipeline (change 017).
    private(set) var filterSamples: [RollFilter: [CGImage]] = [:]

    // Join Roll input fields
    /// The typed join code (change 019): letters / numbers, uppercased, at most 6. The boxes only display it.
    private(set) var joinCode: String = ""
    var joinErrorMessage: String?

    // Lobby (change 011)
    var isInviteSheetPresented: Bool = false
    var isShareSheetPresented: Bool = false
    /// Change 019: Invite Friends sheet page, AirDrop-only share inside it, Delete Room confirmation.
    var invitePage: InvitePage = .options
    var isAirDropSheetPresented: Bool = false
    var isDeleteRoomConfirmationPresented: Bool = false
    /// Share Room could not get the invite link.
    var shareErrorMessage: String?
    private(set) var lobbyParticipants: [RoomParticipant] = []
    /// Short message shown on the Workbench after being removed or after the roll was deleted [Draft].
    var roomExitMessage: String? {
        get { sessionStore.roomExitMessage }
        set { sessionStore.roomExitMessage = newValue }
    }
    /// Invite link state for the host's Invite sheet.
    private(set) var isCreatingInviteLink = false
    /// When the join on screen started; `nil` = no Joining overlay (change 024).
    private(set) var joinStartedAt: Date?
    @ObservationIgnored private var joinAttempt: UUID?
    private(set) var inviteLinkError: String?

    // Alerts and banners
    var showLastSlotRaceAlert: Bool = false
    var lastSlotRaceMessage: String = "The roll just finished! Another friend took the final shot first, so your last photo was dropped."
    var hostHandoverBanner: String?

    // End roll & roll complete popups (Figma 1517:25254 & 1512:26505)
    var showEndRollConfirmation: Bool = false
    var showRollCompletePopup: Bool = false
    var isRollEndedEarly: Bool = false

    // Shutter animation state
    private(set) var isShutterPressed: Bool = false
    @ObservationIgnored private var shutterPressSequence: Int = 0
    @ObservationIgnored private(set) var shutterAnimationTask: Task<Void, Never>?

    // Sync state (change 058)
    /// True while background CloudKit slot claims or photo sync is actively in flight.
    private(set) var isSyncingShot: Bool = false

    #if DEBUG
    /// Last shot taken on this device, for the debug Live Photo viewer (DEBUG builds only).
    private(set) var debugLastShot: ScrapPhoto?
    #endif

    private let modelContext: ModelContext
    let cloudService: CloudKitSessionService
    let sessionStore: SessionStore
    let realtimeService: any RollSlotRealtimeProviding
    @ObservationIgnored private weak var navigator: (any Navigator)?
    @ObservationIgnored lazy var camera = CameraController()
    @ObservationIgnored let roomService: any RollRoomServicing
    @ObservationIgnored private lazy var archiveSync = ScrapbookArchiveSync(modelContext: modelContext, roomService: roomService)
    @ObservationIgnored private var lobbyRefreshTask: Task<Void, Never>?
    @ObservationIgnored var lastSlotClaimTask: Task<Void, Never>?
    /// Change 020: a shot uploads only when its slot claim is confirmed and its Live Photo movie is saved.
    @ObservationIgnored private var shotsAwaitingClaim: Set<UUID> = []
    @ObservationIgnored private var shotsAwaitingMovie: Set<UUID> = []
    @ObservationIgnored private(set) var finalizeSessionTask: Task<Void, Never>?
    @ObservationIgnored private var roomChangeObserver: NSObjectProtocol?
    @ObservationIgnored private var activeLobbyUser: UserProfile?

    deinit {
        finalizeSessionTask?.cancel()
        lobbyRefreshTask?.cancel()
        shutterAnimationTask?.cancel()
        lastSlotClaimTask?.cancel()
    }

    /// How often the lobby re-reads the room when no push arrives.
    static let lobbyRefreshInterval: Duration = .seconds(4)

    // Messages [Draft]
    static let roomRemovedMessage = "The host removed you from the roll"
    static let roomDeletedMessage = "This roll was deleted"
    static let joinNotFoundMessage = "No roll found for this code"
    static let joinEndedMessage = "This roll has ended"
    static let joinOfflineMessage = "You're offline. Connect to the internet to join."
    static let joinUnavailableMessage = "Couldn't join. Make sure you're signed in to iCloud and try again."
    static let joinCodeLength = 6
    static let joinIncompleteCodeMessage = "Enter all 6 characters of the code"
    private static let log = Logger(subsystem: "ScrapIt", category: "RollRoom")
    static let inviteLinkFailedMessage = "Couldn't create the invite link. Check iCloud and your connection, then try again."

    init(
        modelContext: ModelContext,
        navigator: (any Navigator)? = nil,
        sessionStore: SessionStore,
        cloudService: CloudKitSessionService? = nil,
        roomService: (any RollRoomServicing)? = nil,
        realtimeService: (any RollSlotRealtimeProviding)? = nil
    ) {
        self.modelContext = modelContext
        self.navigator = navigator
        self.sessionStore = sessionStore
        self.cloudService = cloudService ?? CloudKitSessionService(modelContext: modelContext)
        self.roomService = roomService ?? CloudKitRollRoomService()
        self.realtimeService = realtimeService ?? (
            SupabaseConfig.load().map { SupabaseRollSlotRealtimeService(config: $0) }
                ?? NoopRollSlotRealtimeService()
        )
    }

    // MARK: - Derived state for Views

    var activeSession: CaptureSession? {
        sessionStore.activeSession
    }

    var enteredJoinCode: String { joinCode }

    /// Room code page of the Invite Friends sheet.
    var roomCode: String { activeSession?.rollCode ?? "" }

    var lobbyRollCodeCharacters: [String] {
        (activeSession?.rollCode ?? "N4B13L").map { String($0) }
    }

    var lobbyJoinedCount: Int {
        lobbyParticipants.isEmpty ? (activeSession?.participantIDs.count ?? 1) : lobbyParticipants.count
    }

    /// Share content once the iCloud link exists (host only).
    var inviteContent: RollInviteContent? {
        guard let session = activeSession,
              let link = session.shareURLString.flatMap(URL.init(string:)) else { return nil }
        return RollInviteContent(rollName: session.name, rollCode: session.rollCode, link: link)
    }

    /// Lobby grid: everyone, then the "+" tile for the host only (change 019).
    func lobbyTiles(currentUser: UserProfile) -> [LobbyTile] {
        lobbyParticipants.map(LobbyTile.participant) + (isHost(currentUser) ? [.invite] : [])
    }

    /// Host can remove anyone but themselves.
    func canRemove(_ participant: RoomParticipant, currentUser: UserProfile) -> Bool {
        isHost(currentUser) && participant.userID != currentUser.appleUserID
    }

    /// Up to two initials from the name ("Sanny" → "S", "Brian Chang" → "BC").
    static func initials(for name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }

    /// Shots taken so far, counting up from 00 to the roll size.
    var takenShotsText: String {
        String(format: "%02d", activeSession?.slotsUsed ?? 0)
    }

    /// Remaining shots left on the active roll (change 041, 058), counting down to 0.
    /// Holds count while background slot claims are in flight until CloudKit confirms.
    var shotsRemaining: Int {
        guard let session = activeSession else { return 0 }
        let confirmedSlotsUsed = max(0, session.slotsUsed - shotsAwaitingClaim.count)
        return max(0, session.rollSize - confirmedSlotsUsed)
    }

    var shotsRemainingText: String {
        "\(shotsRemaining)"
    }

    var totalShotsText: String {
        "/\(activeSession?.rollSize ?? 36)"
    }

    var queuedShotCount: Int {
        cloudService.queuedOfflineCount
    }

    var showsOfflineStatus: Bool {
        !cloudService.isOnline || cloudService.queuedOfflineCount > 0
    }

    var participantCount: Int {
        activeSession?.participantIDs.count ?? 1
    }

    func isHost(_ user: UserProfile) -> Bool {
        activeSession?.hostUserID == user.appleUserID
    }

    // MARK: - Navigation

    /// Choose Filter page (change 017): renders each filter's samples once.
    func loadFilterSamples(renderer: FilterSampleRenderer = .shared) async {
        for filter in RollFilter.allCases where filterSamples[filter] == nil {
            filterSamples[filter] = await renderer.samples(for: filter)
        }
    }

    func startCreateRollWizard() {
        draftRollName = ""
        draftShotCount = 36
        draftFilter = .colorPrint200
        navigator?.push(.createRollSetup)
    }

    func proceedToFilterStep() {
        navigator?.push(.createRollFilter)
    }

    func openJoinRoll() {
        prepareJoin()
        navigator?.push(.joinRoll)
    }

    /// Clears the code when the Join Roll screen opens (also when opened from the Workbench).
    func prepareJoin() {
        joinCode = ""
        joinErrorMessage = nil
    }

    /// Change 019: one text field holds the whole code, so backspace, editing and paste work naturally.
    func updateJoinCode(_ text: String) {
        let cleaned = String(text.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(Self.joinCodeLength))
        if cleaned != joinCode { joinErrorMessage = nil }
        joinCode = cleaned
    }

    func joinCodeCharacter(at index: Int) -> String {
        let characters = Array(joinCode)
        return index < characters.count ? String(characters[index]) : ""
    }

    // MARK: - Create roll

    func createLobbySession(
        currentUser: UserProfile
    ) {
        let trimmedName = draftRollName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Untitled Roll" : trimmedName

        let session = CaptureSession(
            name: resolvedName,
            hostUserID: currentUser.appleUserID,
            participantIDs: [currentUser.appleUserID],
            participantNames: [currentUser.name],
            rollSize: draftShotCount,
            slotsUsed: 0,
            filter: draftFilter,
            status: .waiting
        )
        session.rollKey = RollShotCrypto.newRollKey()
        modelContext.insert(session)
        try? modelContext.save()
        sessionStore.activeSession = session
        lobbyParticipants = [participant(currentUser)]

        navigator?.push(.createRollLobby)

        Task { await createInviteLinkIfNeeded(currentUser: currentUser) }
    }

    /// Creates the CloudKit room and its iCloud link. Called on create, and again from the Invite sheet
    /// while the link is missing. Without iCloud the lobby still works locally; sharing stays unavailable.
    func createInviteLinkIfNeeded(currentUser: UserProfile) async {
        guard let session = activeSession, session.shareURLString == nil, isHost(currentUser), !isCreatingInviteLink else {
            return
        }
        isCreatingInviteLink = true
        inviteLinkError = nil
        defer { isCreatingInviteLink = false }
        let draft = RoomDraft(
            sessionID: session.id,
            rollCode: session.rollCode,
            name: session.name,
            rollSize: session.rollSize,
            filterRaw: session.filterRaw,
            host: participant(currentUser),
            rollKey: session.rollKey
        )
        do {
            let snapshot = try await roomService.createRoom(draft)
            apply(snapshot, to: session)
        } catch {
            logRoomFailure("create invite link", error)
            inviteLinkError = Self.inviteLinkFailedMessage
        }
    }

    func startRollCapture() {
        guard let session = activeSession else { return }
        session.status = .live
        session.startTime = .now
        try? modelContext.save()

        Task {
            await cloudService.publishSessionToCloudKit(session: session)
        }

        beginLivePolling(session: session)
        navigator?.push(.captureSession)
    }

    // MARK: - Join roll

    func joinRollWithCode(
        code: String,
        currentUser: UserProfile
    ) async {
        guard !isJoining else { return }
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleaned.count == Self.joinCodeLength else {
            joinErrorMessage = Self.joinIncompleteCodeMessage
            return
        }
        guard cloudService.isOnline else {
            joinErrorMessage = Self.joinOfflineMessage
            return
        }
        let attempt = beginJoin()
        do {
            let snapshot = try await roomService.joinRoom(code: cleaned, as: participant(currentUser))
            guard finishJoin(attempt) else {
                await leaveCancelledJoin(snapshot, currentUser: currentUser)
                return
            }
            joinErrorMessage = nil
            enterRoom(snapshot)
        } catch {
            guard finishJoin(attempt) else { return }
            logRoomFailure("join", error)
            joinErrorMessage = Self.joinMessage(for: error)
        }
    }

    func submitJoinCode(currentUser: UserProfile) async {
        await joinRollWithCode(
            code: enteredJoinCode,
            currentUser: currentUser
        )
    }

    /// An iCloud share link opened by tap or AirDrop.
    func acceptIncomingShare(_ metadata: CKShare.Metadata, currentUser: UserProfile) async {
        guard !isJoining else { return }
        let attempt = beginJoin()
        do {
            let snapshot = try await roomService.acceptShare(metadata, as: participant(currentUser))
            guard finishJoin(attempt) else {
                await leaveCancelledJoin(snapshot, currentUser: currentUser)
                return
            }
            enterRoom(snapshot)
        } catch {
            guard finishJoin(attempt) else { return }
            logRoomFailure("accept share", error)
            roomExitMessage = Self.joinMessage(for: error)
        }
    }

    // MARK: - Joining overlay (change 024)

    /// Status text under the Joining animation by wait time [Draft text].
    static let joinStatusSteps: [(after: TimeInterval, text: String)] = [
        (0, "Finding the roll…"),
        (3, "Loading the film…"),
        (8, "Almost there…"),
    ]

    var isJoining: Bool { joinStartedAt != nil }

    static func joinStatusText(elapsed: TimeInterval) -> String {
        joinStatusSteps.last { elapsed >= $0.after }?.text ?? joinStatusSteps[0].text
    }

    func joinStatusText(at date: Date) -> String {
        Self.joinStatusText(elapsed: joinStartedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    /// Closes the overlay. The CloudKit request can't be stopped: a late failure is ignored, a late success is
    /// undone with Leave Room.
    func cancelJoin() {
        joinAttempt = nil
        joinStartedAt = nil
    }

    private func beginJoin() -> UUID {
        let attempt = UUID()
        joinAttempt = attempt
        joinStartedAt = .now
        return attempt
    }

    /// Ends the overlay for this attempt. `false` when it was cancelled.
    private func finishJoin(_ attempt: UUID) -> Bool {
        guard joinAttempt == attempt else { return false }
        joinAttempt = nil
        joinStartedAt = nil
        return true
    }

    /// The join finished after Cancel: leave again so the name doesn't stay in the host's lobby. Opened as the host
    /// (same iCloud, own zone): nothing to leave.
    private func leaveCancelledJoin(_ snapshot: RoomSnapshot, currentUser: UserProfile) async {
        guard snapshot.hostUserID != currentUser.appleUserID, let owner = snapshot.zoneOwnerName else { return }
        try? await roomService.leaveRoom(code: snapshot.rollCode, zoneOwnerName: owner, userID: currentUser.appleUserID)
    }

    /// Technical CloudKit detail goes to the Xcode console for developers, never on screen (change 019).
    private func logRoomFailure(_ action: String, _ error: Error) {
        let detail = roomService.lastErrorDescription ?? String(describing: error)
        Self.log.error("\(action, privacy: .public) failed: \(detail, privacy: .public)")
    }

    func handleIncomingURL(
        _ url: URL,
        currentUser: UserProfile
    ) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        if let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
           let code = codeItem.value,
           code.count == 6 {
            Task {
                await joinRollWithCode(
                    code: code,
                    currentUser: currentUser
                )
            }
        }
    }

    static func joinMessage(for error: Error) -> String {
        switch error as? RoomError {
        case .notFound: joinNotFoundMessage
        case .ended: joinEndedMessage
        case .offline: joinOfflineMessage
        case .deleted: roomDeletedMessage
        case .removed: roomRemovedMessage
        case .unavailable, nil: joinUnavailableMessage
        }
    }

    private func participant(_ user: UserProfile) -> RoomParticipant {
        RoomParticipant(
            userID: user.appleUserID,
            name: user.name,
            avatarData: ProfileAvatarProcessor.thumbnail(
                from: user.avatarData,
                maxPixelSize: 200,
                compressionQuality: 0.7
            )
        )
    }

    /// Opens the lobby (or the camera if the roll is already live: late joining).
    private func enterRoom(_ snapshot: RoomSnapshot) {
        let session = localSession(for: snapshot)
        apply(snapshot, to: session)
        sessionStore.activeSession = session
        if session.status == .live {
            beginLivePolling(session: session)
            navigator?.setStack([.captureSession])
        } else {
            navigator?.setStack([.createRollLobby])
        }
    }

    private func localSession(for snapshot: RoomSnapshot) -> CaptureSession {
        let id = snapshot.sessionID
        let descriptor = FetchDescriptor<CaptureSession>(predicate: #Predicate { $0.id == id })
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let session = CaptureSession(
            id: snapshot.sessionID,
            name: snapshot.name,
            rollCode: snapshot.rollCode,
            hostUserID: snapshot.hostUserID,
            participantIDs: [],
            participantNames: [],
            rollSize: snapshot.rollSize
        )
        modelContext.insert(session)
        return session
    }

    /// Copies the room state from CloudKit into the local session.
    func apply(_ snapshot: RoomSnapshot, to session: CaptureSession) {
        session.name = snapshot.name
        session.hostUserID = snapshot.hostUserID
        session.rollSize = snapshot.rollSize
        session.slotsUsed = max(session.slotsUsed, snapshot.slotsUsed)
        session.filterRaw = snapshot.filterRaw
        session.statusRaw = snapshot.statusRaw
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
        try? modelContext.save()
        if session === activeSession || activeSession == nil {
            lobbyParticipants = snapshot.participants
        }
    }

    // MARK: - Lobby

    func lobbyDidAppear(currentUser: UserProfile? = nil) {
        activeLobbyUser = currentUser
        if lobbyParticipants.isEmpty, let session = activeSession {
            lobbyParticipants = zip(session.participantIDs, session.participantNames).map {
                RoomParticipant(userID: $0.0, name: $0.1)
            }
        }
        if let currentUser {
            let local = participant(currentUser)
            if let index = lobbyParticipants.firstIndex(where: { $0.userID == currentUser.appleUserID }) {
                lobbyParticipants[index] = local
            }
        }
        lobbyRefreshTask?.cancel()
        lobbyRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshLobby()
                try? await Task.sleep(for: Self.lobbyRefreshInterval)
            }
        }
        if roomChangeObserver == nil {
            roomChangeObserver = NotificationCenter.default.addObserver(
                forName: .rollRoomDidChange, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in await self?.refreshLobby() }
            }
        }
    }

    func lobbyDidDisappear() {
        activeLobbyUser = nil
        lobbyRefreshTask?.cancel()
        lobbyRefreshTask = nil
        if let roomChangeObserver {
            NotificationCenter.default.removeObserver(roomChangeObserver)
        }
        roomChangeObserver = nil
    }

    /// Re-reads the room: participants, start by the host, removal, deletion.
    func refreshLobby() async {
        guard let session = activeSession, session.ckRecordName != nil else { return }
        do {
            var snapshot = try await roomService.fetchRoom(code: session.rollCode, zoneOwnerName: session.ckZoneOwnerName)
            guard session === activeSession else { return }
            if let currentUser = activeLobbyUser {
                let local = participant(currentUser)
                if let index = snapshot.participants.firstIndex(where: { $0.userID == currentUser.appleUserID }),
                   snapshot.participants[index].name != local.name || snapshot.participants[index].avatarData != local.avatarData {
                    try? await roomService.updateParticipant(local, inRoom: session.rollCode, zoneOwnerName: session.ckZoneOwnerName)
                    snapshot.participants[index] = local
                }
            }
            apply(snapshot, to: session)
            if session.status == .live, navigator?.path.last == .createRollLobby {
                beginLivePolling(session: session)
                navigator?.push(.captureSession)
            }
        } catch RoomError.removed {
            exitRoom(message: Self.roomRemovedMessage)
        } catch RoomError.deleted {
            exitRoom(message: Self.roomDeletedMessage)
        } catch {
            // Offline or iCloud hiccup: keep the last known state and try again later.
        }
    }

    /// X: back to the Workbench. The roll keeps existing (reopening it is [Open]).
    func closeLobby() {
        OrientationLock.resetToPortrait()
        lobbyDidDisappear()
        isInviteSheetPresented = false
        isShareSheetPresented = false
        sessionStore.activeSession = nil
        lobbyParticipants = []
        navigator?.popToRoot()
    }

    /// Current camera return transition phase (change 086).
    var cameraReturnPhase: CameraReturnPhase {
        navigator?.cameraReturnPhase ?? .idle
    }

    /// Prepares homepage with zoomed-in camera and orientation for return transition (change 086).
    func prepareCameraReturn(angle: Double) {
        navigator?.beginCameraReturn(angle: angle)
    }

    /// Back button on CaptureSessionView (change 041, 086): returns to Homepage.
    func returnToHomepage() {
        OrientationLock.resetToPortrait()
        isInviteSheetPresented = false
        isShareSheetPresented = false
        navigator?.popToRoot()
    }

    // MARK: - Lobby menu and invites (change 019)

    /// "+" tile (host): opens Invite Friends on its first page.
    func presentInviteFriends() {
        invitePage = .options
        isInviteSheetPresented = true
    }

    func showRoomCode() { invitePage = .code }
    func showInviteOptions() { invitePage = .options }

    /// Edit Room: shown in the menu, no action yet [Open].
    func editRoom() {}

    /// Share Room (host and participant): the system share sheet with the invite link.
    func shareRoom(currentUser: UserProfile) async {
        guard await ensureInviteLink(currentUser: currentUser) else { return }
        isShareSheetPresented = true
    }

    /// Invite via AirDrop: the share sheet offering only AirDrop (no public API opens AirDrop directly).
    func inviteViaAirDrop(currentUser: UserProfile) async {
        guard await ensureInviteLink(currentUser: currentUser) else { return }
        isAirDropSheetPresented = true
    }

    private func ensureInviteLink(currentUser: UserProfile) async -> Bool {
        if inviteContent == nil {
            await createInviteLinkIfNeeded(currentUser: currentUser)
        }
        guard inviteContent != nil else {
            shareErrorMessage = Self.inviteLinkFailedMessage
            return false
        }
        return true
    }

    /// Delete Room asks first (HIG); the dialog's Delete calls `deleteRoll()`.
    func requestDeleteRoom() {
        isDeleteRoomConfirmationPresented = true
    }

    /// Host: deletes the room for everyone.
    func deleteRoll() {
        guard let session = activeSession else { return }
        let code = session.rollCode
        let isCloudRoom = session.ckRecordName != nil
        discardLocalSession(session)
        closeLobby()
        if isCloudRoom {
            Task { try? await roomService.deleteRoom(code: code) }
        }
    }

    /// Host: removes someone from the room.
    func removeParticipant(_ participant: RoomParticipant, currentUser: UserProfile) {
        guard canRemove(participant, currentUser: currentUser), let session = activeSession else { return }
        lobbyParticipants.removeAll { $0.userID == participant.userID }
        if let index = session.participantIDs.firstIndex(of: participant.userID) {
            session.participantIDs.remove(at: index)
            if index < session.participantNames.count {
                session.participantNames.remove(at: index)
            }
        }
        try? modelContext.save()
        guard session.ckRecordName != nil else { return }
        let code = session.rollCode
        Task {
            do {
                try await roomService.removeParticipant(userID: participant.userID, fromRoom: code)
            } catch {
                await refreshLobby()
            }
        }
    }

    /// Participant: leaves the room.
    func leaveRoll(currentUser: UserProfile) {
        guard let session = activeSession, !isHost(currentUser) else { return }
        let code = session.rollCode
        let owner = session.ckZoneOwnerName
        discardLocalSession(session)
        closeLobby()
        if let owner {
            Task { try? await roomService.leaveRoom(code: code, zoneOwnerName: owner, userID: currentUser.appleUserID) }
        }
    }

    /// Removed by the host or the roll was deleted: back to the Workbench with a message.
    func exitRoom(message: String) {
        if let session = activeSession {
            discardLocalSession(session)
        }
        closeLobby()
        roomExitMessage = message
    }

    private func discardLocalSession(_ session: CaptureSession) {
        modelContext.delete(session)
        try? modelContext.save()
    }

    private func beginLivePolling(session: CaptureSession) {
        cloudService.startLiveSessionPolling(
            session: session
        ) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.showEndRollConfirmation = false
                self.isRollEndedEarly = session.slotsUsed < session.rollSize
                self.startRollFinalizationSync(for: session)
                self.showRollCompletePopup = true
            }
        }
    }

    // MARK: - Camera screen

    func cameraDidAppear() {
        camera.setFilter(activeSession?.filter ?? .colorPrint200)
        Task { await camera.startSession() }
        cloudService.updateQueuedCount()
        if let session = activeSession {
            beginLivePolling(session: session)
        }
        if let rollCode = activeSession?.rollCode {
            let realtimeService = self.realtimeService
            Task { [weak self] in
                await realtimeService.connect(
                    rollCode: rollCode,
                    onSlotUpdate: { [weak self] incomingSlots in
                        self?.applyRemoteSlotCount(incomingSlots)
                    },
                    onRollEnded: { [weak self] in
                        print("⚡️ [RollFlowViewModel] Received real-time roll_ended event! Showing roll complete popup...")
                        guard let self else { return }
                        Task { @MainActor in
                            if let session = self.activeSession {
                                self.isRollEndedEarly = session.slotsUsed < session.rollSize
                                self.startRollFinalizationSync(for: session)
                            }
                            self.showEndRollConfirmation = false
                            self.showRollCompletePopup = true
                        }
                    }
                )
            }
        }
    }

    func cameraDidDisappear() {
        camera.stopSession()
        cloudService.stopLiveSessionPolling()
        let realtimeService = self.realtimeService
        Task {
            await realtimeService.disconnect()
        }
    }

    func applyRemoteSlotCount(_ incomingSlots: Int) {
        guard let session = activeSession, session.status != .ended else { return }
        let clampedSlots = min(max(session.slotsUsed, incomingSlots), session.rollSize)
        guard clampedSlots != session.slotsUsed || clampedSlots >= session.rollSize else { return }

        session.slotsUsed = clampedSlots
        if session.slotsUsed >= session.rollSize {
            session.status = .ended
            session.endTime = .now
            try? modelContext.save()
            startRollFinalizationSync(for: session)
            isRollEndedEarly = false
            showEndRollConfirmation = false
            showRollCompletePopup = true
        } else {
            try? modelContext.save()
        }
    }

    @discardableResult
    @MainActor
    func triggerShutterAnimation(durationNanoseconds: UInt64 = 120_000_000) -> Task<Void, Never> {
        isShutterPressed = true
        HapticService.shared.playShutterClick()
        shutterPressSequence += 1
        let currentSequence = shutterPressSequence
        let task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: durationNanoseconds)
            if self.shutterPressSequence == currentSequence {
                self.isShutterPressed = false
            }
        }
        shutterAnimationTask = task
        return task
    }

    func shutterTapped(currentUser: UserProfile) async {
        guard camera.canCapture else { return }
        await MainActor.run {
            isSyncingShot = true
            triggerShutterAnimation()
        }
        // Change 020: from the shutter on (photo processing, slot, movie, upload start), the shot finishes
        // even if the user leaves the app right away.
        await BackgroundTime.keepAlive("RollShot") {
            let shot = await camera.captureShot(
                filter: activeSession?.filter ?? .colorPrint200,
                rollName: activeSession?.name ?? "Roll"
            )
            let photo = await recordCapturedShot(
                imageData: shot.imageData,
                currentUser: currentUser,
                expectsLiveMovie: shot.livePhotoMovie != nil
            )
            guard let photo else {
                await MainActor.run {
                    isSyncingShot = !shotsAwaitingClaim.isEmpty
                }
                return
            }
            guard let movieTask = shot.livePhotoMovie else { return }
            // The still is saved first; the filtered Live Photo movie follows when ready.
            let movieData = await movieTask.value
            shotsAwaitingMovie.remove(photo.id)
            guard !photo.isDeleted, photo.modelContext != nil else { return }
            if let movieData {
                photo.livePhotoMovieData = movieData
                try? modelContext.save()
            }
            await uploadShotIfReady(photo)
        }
    }

    /// Change 020: uploads the shot once its claim is confirmed and its movie is saved. Called from the
    /// background claim / movie tasks, never from the shutter itself.
    func uploadShotIfReady(_ photo: ScrapPhoto) async {
        guard !photo.isDeleted,
              !shotsAwaitingClaim.contains(photo.id),
              !shotsAwaitingMovie.contains(photo.id) else { return }
        await cloudService.uploadShot(photo)
    }

    /// Camera Control click / volume down: photo on phones with Camera Control, flip otherwise.
    func primaryButtonPressed(currentUser: UserProfile) {
        camera.handlePrimaryButton {
            Task { await shutterTapped(currentUser: currentUser) }
        }
    }

    @discardableResult
    func recordCapturedShot(
        imageData: Data,
        livePhotoMovieData: Data? = nil,
        currentUser: UserProfile,
        expectsLiveMovie: Bool = false,
        simulateLastSlotConflict: Bool = false
    ) async -> ScrapPhoto? {
        guard let session = activeSession else { return nil }

        // If roll has already finished, reject immediately
        if session.status == .ended || session.slotsUsed >= session.rollSize {
            showLastSlotRaceAlert = true
            finalizeSessionAndOpenScrapbook()
            return nil
        }

        // 1. Optimistic photo creation & local SwiftData save (zero network wait)
        let photo = ScrapPhoto(
            imageData: imageData,
            livePhotoMovieData: livePhotoMovieData,
            caption: "",
            authorID: currentUser.appleUserID,
            authorName: currentUser.name,
            timestamp: .now,
            sourceSessionID: session.id,
            isSyncedToCloud: false
        )
        modelContext.insert(photo)
        shotsAwaitingClaim.insert(photo.id)
        isSyncingShot = true
        if expectsLiveMovie {
            shotsAwaitingMovie.insert(photo.id)
        }

        // 2. Optimistic local increment & immediate Supabase broadcast
        session.slotsUsed += 1
        let optimisticCount = session.slotsUsed
        let optimisticFinished = session.slotsUsed >= session.rollSize
        if optimisticFinished {
            session.status = .ended
            session.endTime = .now
        }
        try? modelContext.save()

        let realtimeService = self.realtimeService
        Task {
            await BackgroundTime.keepAlive("RollSlotBroadcast") {
                await realtimeService.broadcastSlotCount(optimisticCount)
            }
        }

        #if DEBUG
        debugLastShot = photo
        #endif

        // 3. Background authoritative claim with CloudKit retry loop (Spec F3)
        let claimTask = Task(priority: .userInitiated) { @MainActor [weak self] in
            // Change 020: the claim, its broadcast and the upload start finish even if the app goes to the background.
            await BackgroundTime.keepAlive("RollSlotClaim") {
                guard let self else { return }
                await self.resolveSlotClaim(
                    photo: photo,
                    session: session,
                    simulateLastSlotConflict: simulateLastSlotConflict
                )
            }
        }
        self.lastSlotClaimTask = claimTask

        return photo
    }

    func resolveSlotClaim(
        photo: ScrapPhoto,
        session: CaptureSession,
        simulateLastSlotConflict: Bool = false
    ) async {
        let result = await cloudService.claimSlotAtomically(
            session: session,
            simulateRaceOnLastSlot: simulateLastSlotConflict
        )

        shotsAwaitingClaim.remove(photo.id)
        isSyncingShot = !shotsAwaitingClaim.isEmpty
        switch result {
        case .claimed(let authoritativeSlots, let rollFinished):
            session.slotsUsed = authoritativeSlots
            if rollFinished {
                session.status = .ended
                session.endTime = .now
            }
            try? modelContext.save()

            let realtime = self.realtimeService
            Task {
                await BackgroundTime.keepAlive("RollSlotBroadcast") {
                    await realtime.broadcastSlotCount(authoritativeSlots)
                    if rollFinished {
                        await realtime.broadcastRollEnded()
                    }
                }
            }

            if rollFinished {
                startRollFinalizationSync(for: session)
                isRollEndedEarly = false
                showEndRollConfirmation = false
                showRollCompletePopup = true
            }
            // Change 020: confirmed, so the shot uploads now (after End Roll has started, never before it).
            await uploadShotIfReady(photo)

        case .rollAlreadyFinished:
            // First write wins (Spec F3): this user lost the last-slot race; drop photo and notify
            session.slotsUsed = session.rollSize
            session.status = .ended
            session.endTime = .now
            modelContext.delete(photo)
            try? modelContext.save()

            let realtime = self.realtimeService
            Task {
                await realtime.broadcastSlotCount(session.rollSize)
                await realtime.broadcastRollEnded()
            }

            showLastSlotRaceAlert = true
            finalizeSessionAndOpenScrapbook()
        }
    }

    // MARK: - End roll / host handover

    private(set) var isTransitioningToReveal: Bool = false

    func presentEndRollConfirmation() {
        showEndRollConfirmation = true
    }

    func dismissEndRollConfirmation() {
        showEndRollConfirmation = false
    }

    func confirmEndRollByHost(currentUser: UserProfile) {
        guard let session = activeSession,
              session.hostUserID == currentUser.appleUserID else { return }
        // Transition from popup 1 to popup 2 is instant
        showEndRollConfirmation = false
        isRollEndedEarly = session.slotsUsed < session.rollSize
        showRollCompletePopup = true
        session.status = .ended
        session.endTime = .now
        try? modelContext.save()
        let realtime = self.realtimeService
        Task {
            await realtime.broadcastRollEnded()
            await cloudService.publishSessionToCloudKit(session: session)
        }
        startRollFinalizationSync(for: session)
    }

    func endSessionManuallyByHost(
        currentUser: UserProfile,
        showPopup: Bool = false
    ) {
        guard let session = activeSession,
              session.hostUserID == currentUser.appleUserID else { return }
        session.status = .ended
        session.endTime = .now
        try? modelContext.save()
        let realtime = self.realtimeService
        Task {
            await realtime.broadcastRollEnded()
            await cloudService.publishSessionToCloudKit(session: session)
        }
        if showPopup {
            showEndRollConfirmation = false
            isRollEndedEarly = session.slotsUsed < session.rollSize
            showRollCompletePopup = true
        } else {
            showEndRollConfirmation = false
            isRollEndedEarly = session.slotsUsed < session.rollSize
            finalizeSessionAndOpenScrapbook()
        }
    }

    func transitionToRollReveal() {
        guard !isTransitioningToReveal else { return }
        isTransitioningToReveal = true
        guard let navigator else {
            proceedToRollReveal()
            isTransitioningToReveal = false
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            navigator.isFadingToReveal = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            UIView.setAnimationsEnabled(false)
            self.proceedToRollReveal()
            DispatchQueue.main.async {
                UIView.setAnimationsEnabled(true)
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeInOut(duration: 0.25)) {
                navigator.isFadingToReveal = false
            }
            self.isTransitioningToReveal = false
        }
    }

    func proceedToRollReveal() {
        showEndRollConfirmation = false
        showRollCompletePopup = false
        finalizeSessionAndOpenScrapbook()
    }

    func handleHostDisconnect(
        disconnectedHostID: String
    ) {
        guard let session = activeSession else { return }
        if let newHostID = cloudService.handoverHostIfNeeded(
            session: session,
            disconnectedUserID: disconnectedHostID
        ) {
            try? modelContext.save()
            hostHandoverBanner = "Host disconnected — host role passed to next participant (\(newHostID.prefix(10)))."
        }
    }

    func simulateHostDisconnect() {
        if let currentHost = activeSession?.hostUserID {
            handleHostDisconnect(disconnectedHostID: currentHost)
        }
    }

    // MARK: - Finalize roll into scrapbook

    /// Restores scrapbooks on a new phone and adds friends' photos to finished rolls (change 012).
    @discardableResult
    func syncScrapbookArchive(for session: CaptureSession? = nil) async -> Int {
        if let session {
            return await archiveSync.syncRoom(for: session)
        } else {
            return await archiveSync.run()
        }
    }

    nonisolated static let friendsShotsSyncInterval: TimeInterval = 3
    nonisolated static let friendsShotsSyncLimit: TimeInterval = 120

    /// End Roll sync goes on while some of the roll's shots are missing here, for up to 2 minutes (change 020).
    nonisolated static func shouldKeepSyncingFriendsShots(localCount: Int, shotsUsed: Int, elapsed: TimeInterval) -> Bool {
        localCount < shotsUsed && elapsed < friendsShotsSyncLimit
    }

    /// One End Roll sync round; true while shots are still missing and time is left.
    private func syncFriendsShotsOnce(for session: CaptureSession, since start: Date) async -> Bool {
        guard session.modelContext != nil else { return false }
        _ = await syncScrapbookArchive(for: session)
        guard session.modelContext != nil else { return false }
        return Self.shouldKeepSyncingFriendsShots(
            localCount: localShotCount(for: session),
            shotsUsed: session.slotsUsed,
            elapsed: Date.now.timeIntervalSince(start)
        )
    }

    private func localShotCount(for session: CaptureSession) -> Int {
        let sessionID = session.id
        let descriptor = FetchDescriptor<ScrapPhoto>(predicate: #Predicate { $0.sourceSessionID == sessionID })
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func startRollFinalizationSync(for session: CaptureSession) {
        let cloud = self.cloudService
        let notReady = shotsAwaitingClaim.union(shotsAwaitingMovie)
        let isCloudRoom = session.ckRecordName != nil
        finalizeSessionTask?.cancel()
        // Holds the ViewModel on purpose: the sync keeps running after the roll screens close (change 020).
        finalizeSessionTask = Task {
            guard session.modelContext != nil else { return }
            await cloud.publishSessionToCloudKit(session: session)
            await cloud.uploadPendingPhotos(for: session, excluding: notReady)
            // A local roll (no iCloud, Simulator) has no friends' shots to wait for: one sync, as before.
            guard isCloudRoom else {
                _ = await self.syncScrapbookArchive(for: session)
                return
            }
            // Change 020: keep fetching friends' shots until all of the roll's shots are here (max 2 minutes).
            // Keeps running after the roll screens close (the reveal screen shows the photos as they arrive).
            let start = Date.now
            while !Task.isCancelled, await self.syncFriendsShotsOnce(for: session, since: start) {
                try? await Task.sleep(for: .seconds(Self.friendsShotsSyncInterval))
            }
        }
    }

    func finalizeSessionAndOpenScrapbook() {
        showEndRollConfirmation = false
        showRollCompletePopup = false
        OrientationLock.resetToPortrait()
        isSyncingShot = false
        if let session = activeSession {
            if finalizeSessionTask == nil {
                startRollFinalizationSync(for: session)
            }
        } else {
            finalizeSessionTask?.cancel()
            finalizeSessionTask = Task { [weak self] in
                _ = await self?.syncScrapbookArchive()
            }
        }
        cloudService.stopLiveSessionPolling()
        let realtimeService = self.realtimeService
        Task {
            await realtimeService.disconnect()
        }
        guard let scrapbook = sessionStore.finalizeActiveSession() else {
            return
        }
        let id = scrapbook.id
        // The photo reveal first (change 021); its "Start Scrapbook" opens the editor.
        if navigator?.path.last != .rollReveal(id) {
            navigator?.setStack([.rollReveal(id)])
        }
    }
}
