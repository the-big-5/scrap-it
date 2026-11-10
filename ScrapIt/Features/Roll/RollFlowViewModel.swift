import CoreGraphics
import CloudKit
import Foundation
import Observation
import OSLog
import SwiftData

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
    private(set) var inviteLinkError: String?

    // Alerts and banners
    var showLastSlotRaceAlert: Bool = false
    var lastSlotRaceMessage: String = "The roll just finished! Another friend took the final shot first, so your last photo was dropped."
    var hostHandoverBanner: String?

    // Shutter animation state
    private(set) var isShutterPressed: Bool = false
    @ObservationIgnored private var shutterPressSequence: Int = 0
    @ObservationIgnored private(set) var shutterAnimationTask: Task<Void, Never>?

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
    @ObservationIgnored private(set) var finalizeSessionTask: Task<Void, Never>?
    @ObservationIgnored private var roomChangeObserver: NSObjectProtocol?

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

    /// Remaining shots left on the active roll (change 041), counting down to 0.
    var shotsRemaining: Int {
        guard let session = activeSession else { return 0 }
        return max(0, session.rollSize - session.slotsUsed)
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
        lobbyParticipants = [RoomParticipant(userID: currentUser.appleUserID, name: currentUser.name)]

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
            host: RoomParticipant(userID: currentUser.appleUserID, name: currentUser.name),
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
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleaned.count == Self.joinCodeLength else {
            joinErrorMessage = Self.joinIncompleteCodeMessage
            return
        }
        guard cloudService.isOnline else {
            joinErrorMessage = Self.joinOfflineMessage
            return
        }
        do {
            let snapshot = try await roomService.joinRoom(code: cleaned, as: participant(currentUser))
            joinErrorMessage = nil
            enterRoom(snapshot)
        } catch {
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
        do {
            let snapshot = try await roomService.acceptShare(metadata, as: participant(currentUser))
            enterRoom(snapshot)
        } catch {
            logRoomFailure("accept share", error)
            roomExitMessage = Self.joinMessage(for: error)
        }
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
        RoomParticipant(userID: user.appleUserID, name: user.name)
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

    func lobbyDidAppear() {
        if lobbyParticipants.isEmpty, let session = activeSession {
            lobbyParticipants = zip(session.participantIDs, session.participantNames).map {
                RoomParticipant(userID: $0.0, name: $0.1)
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
            let snapshot = try await roomService.fetchRoom(code: session.rollCode, zoneOwnerName: session.ckZoneOwnerName)
            guard session === activeSession else { return }
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

    /// Back button on CaptureSessionView (change 041): returns to Homepage.
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
            self.finalizeSessionAndOpenScrapbook()
        }
    }

    // MARK: - Camera screen

    func cameraDidAppear() {
        camera.setFilter(activeSession?.filter ?? .colorPrint200)
        Task { await camera.startSession() }
        cloudService.updateQueuedCount()
        if let rollCode = activeSession?.rollCode {
            let realtimeService = self.realtimeService
            Task { [weak self] in
                await realtimeService.connect(
                    rollCode: rollCode,
                    onSlotUpdate: { [weak self] incomingSlots in
                        self?.applyRemoteSlotCount(incomingSlots)
                    },
                    onRollEnded: { [weak self] in
                        print("⚡️ [RollFlowViewModel] Received real-time roll_ended event! Finalizing session...")
                        self?.finalizeSessionAndOpenScrapbook()
                    }
                )
            }
        }
    }

    func cameraDidDisappear() {
        camera.stopSession()
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
            finalizeSessionAndOpenScrapbook()
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
            triggerShutterAnimation()
        }
        let shot = await camera.captureShot(
            filter: activeSession?.filter ?? .colorPrint200,
            rollName: activeSession?.name ?? "Roll"
        )
        let photo = await recordCapturedShot(
            imageData: shot.imageData,
            currentUser: currentUser
        )
        guard let photo, let movieTask = shot.livePhotoMovie else { return }
        // The still is saved first; the filtered Live Photo movie follows when ready.
        if let movieData = await movieTask.value {
            guard photo.modelContext != nil else { return }
            photo.livePhotoMovieData = movieData
            try? modelContext.save()
            // If the roll already ended while movie was encoding, ensure this photo gets uploaded with movie (change 015).
            if let session = activeSession, session.status == .ended {
                photo.isSyncedToCloud = false
                try? modelContext.save()
                let cloud = self.cloudService
                Task {
                    await cloud.uploadPendingPhotos(for: session)
                }
            }
        }
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
            await realtimeService.broadcastSlotCount(optimisticCount)
        }

        #if DEBUG
        debugLastShot = photo
        #endif

        // 3. Background authoritative claim with CloudKit retry loop (Spec F3)
        let claimTask = Task(priority: .userInitiated) { @MainActor [weak self] in
            guard let self else { return }
            await self.resolveSlotClaim(
                photo: photo,
                session: session,
                simulateLastSlotConflict: simulateLastSlotConflict
            )
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
                await realtime.broadcastSlotCount(authoritativeSlots)
                if rollFinished {
                    await realtime.broadcastRollEnded()
                }
            }

            if rollFinished {
                finalizeSessionAndOpenScrapbook()
            }

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

    func endSessionManuallyByHost(
        currentUser: UserProfile
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

    func finalizeSessionAndOpenScrapbook() {
        OrientationLock.resetToPortrait()
        if let session = activeSession {
            let cloud = self.cloudService
            finalizeSessionTask?.cancel()
            finalizeSessionTask = Task { [weak self] in
                await cloud.publishSessionToCloudKit(session: session)
                await cloud.uploadPendingPhotos(for: session)
                _ = await self?.syncScrapbookArchive(for: session)
                // Targeted sync polling over a window so friends' incoming shots are pulled automatically
                for delay in [2, 3, 5] {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled, let self else { return }
                    _ = await self.syncScrapbookArchive(for: session)
                }
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
        // Straight into the scrapbook editor (change 013).
        if navigator?.path.last != .scrapbook(id) {
            navigator?.setStack([.scrapbook(id)])
        }
    }
}
