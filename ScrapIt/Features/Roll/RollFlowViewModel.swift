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

    // Join Roll input fields
    var joinCodeCharacters: [String] = Array(repeating: "", count: 6)
    var joinErrorMessage: String?

    // Lobby sheet
    var isInviteSheetPresented: Bool = false

    // Alerts and banners
    var showLastSlotRaceAlert: Bool = false
    var lastSlotRaceMessage: String = "The roll just finished! Another friend took the final shot first, so your last photo was dropped."
    var hostHandoverBanner: String?

    #if DEBUG
    /// Last shot taken on this device, for the debug Live Photo viewer (DEBUG builds only).
    private(set) var debugLastShot: ScrapPhoto?
    #endif

    private let modelContext: ModelContext
    let cloudService: CloudKitSessionService
    let sessionStore: SessionStore
    @ObservationIgnored private weak var navigator: (any Navigator)?
    @ObservationIgnored lazy var camera = CameraController()

    init(
        modelContext: ModelContext,
        navigator: (any Navigator)? = nil,
        sessionStore: SessionStore,
        cloudService: CloudKitSessionService? = nil
    ) {
        self.modelContext = modelContext
        self.navigator = navigator
        self.sessionStore = sessionStore
        self.cloudService = cloudService ?? CloudKitSessionService(modelContext: modelContext)
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

    var lobbyQRPayload: String {
        activeSession?.inviteURL.absoluteString ?? "scrapit://join?code=N4B13L"
    }

    var lobbyJoinedCount: Int {
        activeSession?.participantIDs.count ?? 1
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
        joinCodeCharacters = Array(repeating: "", count: 6)
        joinErrorMessage = nil
        navigator?.push(.joinRoll)
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
        modelContext.insert(session)
        try? modelContext.save()
        sessionStore.activeSession = session

        Task {
            await cloudService.publishSessionToCloudKit(session: session)
        }

        navigator?.push(.createRollLobby)
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

        do {
            let joined = try await cloudService.fetchOrJoinSession(
                rollCode: cleaned,
                userID: currentUser.appleUserID,
                userName: currentUser.name
            )
            sessionStore.activeSession = joined
            joinErrorMessage = nil

            if joined.status == .live {
                beginLivePolling(session: joined)
                navigator?.push(.captureSession)
            } else {
                navigator?.push(.createRollLobby)
            }
        } catch {
            joinErrorMessage = error.localizedDescription
        }
    }

    func submitJoinCode(currentUser: UserProfile) async {
        await joinRollWithCode(
            code: enteredJoinCode,
            currentUser: currentUser
        )
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
    }

    func cameraDidDisappear() {
        camera.stopSession()
    }

    func shutterTapped(currentUser: UserProfile) async {
        guard camera.canCapture else { return }
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
        case .claimed(_, let rollFinished):
            let photo = ScrapPhoto(
                imageData: imageData,
                livePhotoMovieData: livePhotoMovieData,
                caption: "",
                authorID: currentUser.appleUserID,
                authorName: currentUser.name,
                timestamp: .now,
                sourceSessionID: session.id,
                isSyncedToCloud: cloudService.isOnline
            )
            modelContext.insert(photo)
            try? modelContext.save()

            await cloudService.enqueueOrUploadPhoto(
                photo: photo,
                session: session
            )

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

    func finalizeSessionAndOpenScrapbook() {
        cloudService.stopLiveSessionPolling()
        guard let scrapbook = sessionStore.finalizeActiveSession() else {
            return
        }
        let id = scrapbook.id
        if navigator?.path.last != .scrapbookGrid(id) {
            navigator?.setStack([.scrapbookGrid(id)])
        }
    }
}
