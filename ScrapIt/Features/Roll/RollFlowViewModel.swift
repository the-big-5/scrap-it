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

    let cloudService: CloudKitSessionService
    @ObservationIgnored let sessionStore: SessionStore
    @ObservationIgnored private weak var navigator: (any Navigator)?
    @ObservationIgnored lazy var camera = CameraController()

    // Test hook kept from existing ScrapItTests target.
    var arr = false
    func yangBisaDiTest() {
        arr = true
    }

    init(
        navigator: (any Navigator)? = nil,
        sessionStore: SessionStore = SessionStore(),
        cloudService: CloudKitSessionService = .shared
    ) {
        self.navigator = navigator
        self.sessionStore = sessionStore
        self.cloudService = cloudService
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

    var remainingShotsText: String {
        String(format: "%02d", activeSession?.remainingSlots ?? 36)
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
        currentUser: UserProfile,
        modelContext: ModelContext
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

    func startRollCapture(modelContext: ModelContext) {
        guard let session = activeSession else { return }
        session.status = .live
        session.startTime = .now
        try? modelContext.save()

        Task {
            await cloudService.publishSessionToCloudKit(session: session)
        }

        beginLivePolling(session: session, modelContext: modelContext)
        navigator?.push(.captureSession)
    }

    // MARK: - Join roll

    func joinRollWithCode(
        code: String,
        currentUser: UserProfile,
        modelContext: ModelContext
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
                userName: currentUser.name,
                modelContext: modelContext
            )
            sessionStore.activeSession = joined
            joinErrorMessage = nil

            if joined.status == .live {
                beginLivePolling(session: joined, modelContext: modelContext)
                navigator?.push(.captureSession)
            } else {
                navigator?.push(.createRollLobby)
            }
        } catch {
            joinErrorMessage = error.localizedDescription
        }
    }

    func submitJoinCode(currentUser: UserProfile, modelContext: ModelContext) async {
        await joinRollWithCode(
            code: enteredJoinCode,
            currentUser: currentUser,
            modelContext: modelContext
        )
    }

    func handleIncomingURL(
        _ url: URL,
        currentUser: UserProfile,
        modelContext: ModelContext
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
                    currentUser: currentUser,
                    modelContext: modelContext
                )
            }
        }
    }

    private func beginLivePolling(session: CaptureSession, modelContext: ModelContext) {
        cloudService.startLiveSessionPolling(
            session: session,
            modelContext: modelContext
        ) { [weak self] in
            guard let self else { return }
            self.finalizeSessionAndOpenScrapbook(modelContext: modelContext)
        }
    }

    // MARK: - Camera screen

    func cameraDidAppear(modelContext: ModelContext) {
        camera.startSession()
        cloudService.updateQueuedCount(modelContext: modelContext)
    }

    func cameraDidDisappear() {
        camera.stopSession()
    }

    func shutterTapped(currentUser: UserProfile, modelContext: ModelContext) async {
        let imageData = await camera.captureShot(
            filter: activeSession?.filter ?? .colorPrint200,
            rollName: activeSession?.name ?? "Roll"
        )
        await recordCapturedShot(
            imageData: imageData,
            livePhotoMovieData: camera.isLivePhotoEnabled ? Data("live".utf8) : nil,
            currentUser: currentUser,
            modelContext: modelContext
        )
    }

    func recordCapturedShot(
        imageData: Data,
        livePhotoMovieData: Data? = nil,
        currentUser: UserProfile,
        modelContext: ModelContext,
        simulateLastSlotConflict: Bool = false
    ) async {
        guard let session = activeSession else { return }

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
                session: session,
                modelContext: modelContext
            )

            if rollFinished {
                finalizeSessionAndOpenScrapbook(modelContext: modelContext)
            }

        case .rollAlreadyFinished:
            // First write wins; this user's shot is dropped and the user is notified
            showLastSlotRaceAlert = true
            finalizeSessionAndOpenScrapbook(modelContext: modelContext)
        }
    }

    // MARK: - End roll / host handover

    func endSessionManuallyByHost(
        currentUser: UserProfile,
        modelContext: ModelContext
    ) {
        guard let session = activeSession,
              session.hostUserID == currentUser.appleUserID else { return }
        session.status = .ended
        session.endTime = .now
        try? modelContext.save()
        Task {
            await cloudService.publishSessionToCloudKit(session: session)
        }
        finalizeSessionAndOpenScrapbook(modelContext: modelContext)
    }

    func handleHostDisconnect(
        disconnectedHostID: String,
        modelContext: ModelContext
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

    func simulateHostDisconnect(modelContext: ModelContext) {
        if let currentHost = activeSession?.hostUserID {
            handleHostDisconnect(disconnectedHostID: currentHost, modelContext: modelContext)
        }
    }

    // MARK: - Finalize roll into scrapbook

    func finalizeSessionAndOpenScrapbook(modelContext: ModelContext) {
        cloudService.stopLiveSessionPolling()
        guard let scrapbook = sessionStore.finalizeActiveSession(modelContext: modelContext) else {
            return
        }
        let id = scrapbook.id
        if navigator?.path.last != .scrapbookGrid(id) {
            navigator?.setStack([.scrapbookGrid(id)])
        }
    }
}
