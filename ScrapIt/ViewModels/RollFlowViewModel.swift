import Foundation
import Observation
import SwiftData
import SwiftUI

enum AppTab: String {
    case home
    case profile
}

enum RollRoute: Hashable {
    case cameraRollMenu
    case createStep1NameAndShots
    case createStep2ChooseFilter
    case createStep3ShareRoom
    case joinRoll
    case captureSession
    case scrapbookGrid(UUID)
}

@Observable
final class RollFlowViewModel {
    static let availableShotCounts = [24, 36, 48, 72]

    var selectedTab: AppTab = .home
    var navigationPath: [RollRoute] = []

    // Create Roll draft fields
    var draftRollName: String = ""
    var draftShotCount: Int = 36
    var draftFilter: RollFilter = .colorPrint200

    // Join Roll input fields
    var joinCodeCharacters: [String] = Array(repeating: "", count: 6)
    var joinErrorMessage: String?

    // Active session & alerts
    var activeSession: CaptureSession?
    var activeScrapbook: Scrapbook?
    var showLastSlotRaceAlert: Bool = false
    var lastSlotRaceMessage: String = "The roll just finished! Another friend took the final shot first, so your last photo was dropped."
    var hostHandoverBanner: String?

    let cloudService = CloudKitSessionService.shared

    var enteredJoinCode: String {
        joinCodeCharacters.joined().uppercased()
    }

    // MARK: - Navigation Helpers

    func openCameraRollMenu() {
        navigationPath = [.cameraRollMenu]
    }

    func startCreateRollWizard() {
        draftRollName = ""
        draftShotCount = 36
        draftFilter = .colorPrint200
        navigationPath.append(.createStep1NameAndShots)
    }

    func proceedToFilterStep() {
        navigationPath.append(.createStep2ChooseFilter)
    }

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
        activeSession = session

        Task {
            await cloudService.publishSessionToCloudKit(session: session)
        }

        navigationPath.append(.createStep3ShareRoom)
    }

    func startRollCapture(modelContext: ModelContext) {
        guard let session = activeSession else { return }
        session.status = .live
        session.startTime = .now
        try? modelContext.save()

        Task {
            await cloudService.publishSessionToCloudKit(session: session)
        }

        cloudService.startLiveSessionPolling(
            session: session,
            modelContext: modelContext
        ) { [weak self] in
            guard let self else { return }
            self.finalizeSessionAndOpenScrapbook(modelContext: modelContext)
        }

        navigationPath.append(.captureSession)
    }

    func openJoinRoll() {
        joinCodeCharacters = Array(repeating: "", count: 6)
        joinErrorMessage = nil
        navigationPath.append(.joinRoll)
    }

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
            joined.status = .live
            activeSession = joined
            joinErrorMessage = nil

            cloudService.startLiveSessionPolling(
                session: joined,
                modelContext: modelContext
            ) { [weak self] in
                guard let self else { return }
                self.finalizeSessionAndOpenScrapbook(modelContext: modelContext)
            }

            navigationPath.append(.captureSession)
        } catch {
            joinErrorMessage = error.localizedDescription
        }
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

    // MARK: - Capture Shot & Slot Claiming

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

    // MARK: - Host Ends Session or Host Disconnect Handover

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

    // MARK: - Finalize Session → Create New Shared Scrapbook (Basic Grid)

    func finalizeSessionAndOpenScrapbook(modelContext: ModelContext) {
        cloudService.stopLiveSessionPolling()
        guard let session = activeSession else { return }
        session.status = .ended
        if session.endTime == nil {
            session.endTime = .now
        }

        // Check if Scrapbook was already created for this session
        let sessionID = session.id
        let existingDescriptor = FetchDescriptor<Scrapbook>(
            predicate: #Predicate { $0.sourceSessionID == sessionID }
        )
        if let existing = (try? modelContext.fetch(existingDescriptor))?.first {
            activeScrapbook = existing
            attachSessionPhotos(to: existing, sessionID: sessionID, modelContext: modelContext)
            navigateToScrapbook(existing.id)
            return
        }

        let scrapbook = Scrapbook(
            title: session.name,
            createdDate: .now,
            memberIDs: session.participantIDs,
            memberNames: session.participantNames,
            sourceSessionID: session.id
        )
        modelContext.insert(scrapbook)
        session.createdScrapbookID = scrapbook.id

        attachSessionPhotos(to: scrapbook, sessionID: sessionID, modelContext: modelContext)
        try? modelContext.save()

        activeScrapbook = scrapbook
        navigateToScrapbook(scrapbook.id)
    }

    private func attachSessionPhotos(
        to scrapbook: Scrapbook,
        sessionID: UUID,
        modelContext: ModelContext
    ) {
        let photoDescriptor = FetchDescriptor<ScrapPhoto>(
            predicate: #Predicate { $0.sourceSessionID == sessionID },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        if let sessionPhotos = try? modelContext.fetch(photoDescriptor) {
            for photo in sessionPhotos {
                if !scrapbook.photos.contains(where: { $0.id == photo.id }) {
                    scrapbook.photos.append(photo)
                }
            }
            if scrapbook.coverPhotoData == nil, let first = sessionPhotos.first {
                scrapbook.coverPhotoData = first.imageData
            }
        }
    }

    private func navigateToScrapbook(_ id: UUID) {
        if navigationPath.last != .scrapbookGrid(id) {
            navigationPath = [.scrapbookGrid(id)]
        }
    }
}
