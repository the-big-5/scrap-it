import CoreGraphics
import CloudKit
import Foundation
import Observation
import SwiftData

/// Single ViewModel for the Roll feature: create, join, capture and end a roll.
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
    var joinCodeCharacters: [String] = Array(repeating: "", count: 6)
    var joinErrorMessage: String?

    // Lobby (change 011)
    var isInviteSheetPresented: Bool = false
    var isShareSheetPresented: Bool = false
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
    @ObservationIgnored private var roomChangeObserver: NSObjectProtocol?

    /// How often the lobby re-reads the room when no push arrives.
    static let lobbyRefreshInterval: Duration = .seconds(4)

    // Messages [Draft]
    static let roomRemovedMessage = "The host removed you from the roll"
    static let roomDeletedMessage = "This roll was deleted"
    static let joinNotFoundMessage = "No roll found for this code"
    static let joinEndedMessage = "This roll has ended"
    static let joinOfflineMessage = "You're offline. Connect to the internet to join."
    static let joinUnavailableMessage = "Couldn't join. Make sure you're signed in to iCloud and try again."
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

    var enteredJoinCode: String {
        joinCodeCharacters.joined().uppercased()
    }

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

    /// "Copy link": the iCloud link, or the roll code while the link is not ready.
    var inviteCopyText: String {
        activeSession?.shareURLString ?? activeSession?.rollCode ?? ""
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

    /// Clears the code boxes when the Join Roll screen opens (also when opened from the Workbench).
    func prepareJoin() {
        joinCodeCharacters = Array(repeating: "", count: 6)
        joinErrorMessage = nil
    }

    // MARK: - Join code input

    /// Applies typed or pasted text to a code box. Returns the box index that should get focus next.
    func updateJoinCode(at index: Int, with newValue: String) -> Int? {
        let upper = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
        if upper.count > 1 {
            let chars = Array(upper.prefix(6))
            for (offset, ch) in chars.enumerated() where offset < 6 {
                joinCodeCharacters[offset] = String(ch)
            }
            return min(5, chars.count - 1)
        } else {
            let single = String(upper.suffix(1))
            joinCodeCharacters[index] = single
            if !single.isEmpty && index < 5 {
                return index + 1
            }
            return nil
        }
    }

    func joinCodeCharacter(at index: Int) -> String {
        guard index < joinCodeCharacters.count else { return "" }
        return joinCodeCharacters[index]
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
            #if DEBUG
            inviteLinkError = Self.inviteLinkFailedMessage + "\n\(roomService.lastErrorDescription ?? String(describing: error))"
            #else
            inviteLinkError = Self.inviteLinkFailedMessage
            #endif
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
        guard cleaned.count == 6 else {
            joinErrorMessage = RollSessionError.invalidCode.localizedDescription
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
            joinErrorMessage = diagnosed(Self.joinMessage(for: error))
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
            roomExitMessage = diagnosed(Self.joinMessage(for: error))
        }
    }

    /// DEBUG builds add the raw CloudKit error so device problems can be diagnosed.
    private func diagnosed(_ message: String) -> String {
        #if DEBUG
        if let detail = roomService.lastErrorDescription {
            return message + "\n" + detail
        }
        #endif
        return message
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
        lobbyDidDisappear()
        isInviteSheetPresented = false
        isShareSheetPresented = false
        sessionStore.activeSession = nil
        lobbyParticipants = []
        navigator?.popToRoot()
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
                await realtimeService.connect(rollCode: rollCode) { [weak self] incomingSlots in
                    self?.applyRemoteSlotCount(incomingSlots)
                }
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

        let result = await cloudService.claimSlotAtomically(
            session: session,
            simulateRaceOnLastSlot: simulateLastSlotConflict
        )

        switch result {
        case .claimed(let newSlotsUsed, let rollFinished):
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
            try? modelContext.save()

            let realtimeService = self.realtimeService
            Task {
                await realtimeService.broadcastSlotCount(newSlotsUsed)
            }

            #if DEBUG
            debugLastShot = photo
            #endif

            if rollFinished {
                finalizeSessionAndOpenScrapbook()
            }
            return photo

        case .rollAlreadyFinished:
            // First write wins; this user's shot is dropped and the user is notified
            showLastSlotRaceAlert = true
            finalizeSessionAndOpenScrapbook()
            return nil
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
        Task {
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
    func syncScrapbookArchive() async {
        await archiveSync.run()
    }

    func finalizeSessionAndOpenScrapbook() {
        if let session = activeSession {
            let cloud = self.cloudService
            Task {
                await cloud.uploadPendingPhotos(for: session)
                await self.syncScrapbookArchive()
            }
        } else {
            Task { await syncScrapbookArchive() }
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
