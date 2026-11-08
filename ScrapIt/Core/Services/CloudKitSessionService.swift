import CloudKit
import Foundation
import Network
import Observation
import SwiftData

enum SlotClaimResult {
    case claimed(newSlotsUsed: Int, rollFinished: Bool)
    case rollAlreadyFinished
}

@Observable
final class CloudKitSessionService {
    var isOnline: Bool = true
    var queuedOfflineCount: Int = 0
    var lastSyncStatus: String = "CloudKit ready"

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "scrapit.network.monitor")
    private var pollTimer: Timer?
    private let modelContext: ModelContext

    init(
        modelContext: ModelContext,
        enableNetworkMonitoring: Bool = true
    ) {
        self.modelContext = modelContext
        if enableNetworkMonitoring {
            startNetworkMonitoring()
        }
    }

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = online
                if online && wasOffline {
                    self.lastSyncStatus = "Back online — syncing queued shots"
                } else if !online {
                    self.lastSyncStatus = "Offline — shots queued locally"
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Room state (change 011: the room lives in the host's shared zone)

    private func roomLocation(for session: CaptureSession) -> RollRoomLocation {
        RollRoomLocation(rollCode: session.rollCode, zoneOwnerName: session.ckZoneOwnerName)
    }

    /// Pushes status / host / end time of the session to its room record (start, end, host handover).
    func publishSessionToCloudKit(session: CaptureSession) async {
        guard isOnline, session.ckRecordName != nil else { return }
        let location = roomLocation(for: session)
        let database = location.database(in: CKContainer.default())
        guard let record = try? await database.record(for: location.sessionRecordID) else { return }
        record["statusRaw"] = session.statusRaw as CKRecordValue
        record["hostUserID"] = session.hostUserID as CKRecordValue
        record["startTime"] = session.startTime as CKRecordValue
        if let endTime = session.endTime {
            record["endTime"] = endTime as CKRecordValue
        }
        _ = try? await database.save(record)
    }

    // MARK: - Atomic Slot Claim (First Write Wins on Last-Slot Race)

    func claimSlotAtomically(
        session: CaptureSession,
        simulateRaceOnLastSlot: Bool = false
    ) async -> SlotClaimResult {
        if session.status == .ended || session.slotsUsed >= session.rollSize {
            session.status = .ended
            session.endTime = .now
            return .rollAlreadyFinished
        }

        if simulateRaceOnLastSlot && session.remainingSlots == 1 {
            session.slotsUsed = session.rollSize
            session.status = .ended
            session.endTime = .now
            return .rollAlreadyFinished
        }

        // Optimistic concurrency via CloudKit CKModifyRecordsOperation (.ifServerRecordUnchanged)
        if isOnline, session.ckRecordName != nil {
            let location = roomLocation(for: session)
            let recordID = location.sessionRecordID
            let db = location.database(in: CKContainer.default())
            if let serverRecord = try? await db.record(for: recordID) {
                let serverSlotsUsed = (serverRecord["slotsUsed"] as? Int) ?? session.slotsUsed
                let serverRollSize = (serverRecord["rollSize"] as? Int) ?? session.rollSize
                let serverStatus = (serverRecord["statusRaw"] as? String) ?? session.statusRaw

                if serverStatus == SessionStatus.ended.rawValue || serverSlotsUsed >= serverRollSize {
                    session.slotsUsed = serverRollSize
                    session.status = .ended
                    session.endTime = .now
                    return .rollAlreadyFinished
                }

                let nextSlots = serverSlotsUsed + 1
                serverRecord["slotsUsed"] = nextSlots as CKRecordValue
                if nextSlots >= serverRollSize {
                    serverRecord["statusRaw"] = SessionStatus.ended.rawValue as CKRecordValue
                }

                let conflictDetected = await saveRecordIfUnchanged(serverRecord, in: db)
                if conflictDetected {
                    // Re-fetch to see if another user claimed the last slot
                    if let latest = try? await db.record(for: recordID) {
                        let latestUsed = (latest["slotsUsed"] as? Int) ?? nextSlots
                        if latestUsed >= serverRollSize {
                            session.slotsUsed = serverRollSize
                            session.status = .ended
                            session.endTime = .now
                            return .rollAlreadyFinished
                        }
                    }
                }
            }
        }

        session.slotsUsed += 1
        let finished = session.slotsUsed >= session.rollSize
        if finished {
            session.status = .ended
            session.endTime = .now
        }
        return .claimed(newSlotsUsed: session.slotsUsed, rollFinished: finished)
    }

    private func saveRecordIfUnchanged(_ record: CKRecord, in database: CKDatabase) async -> Bool {
        await withCheckedContinuation { continuation in
            let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            op.savePolicy = .ifServerRecordUnchanged
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: false)
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
            database.add(op)
        }
    }

    // MARK: - Host Disconnect Handover

    /// Passes the host role to the next participant if the current host disconnects or leaves.
    func handoverHostIfNeeded(session: CaptureSession, disconnectedUserID: String) -> String? {
        guard session.hostUserID == disconnectedUserID else { return nil }
        session.participantIDs.removeAll { $0 == disconnectedUserID }
        guard let nextHostID = session.participantIDs.first else {
            return nil
        }
        session.hostUserID = nextHostID
        Task {
            await publishSessionToCloudKit(session: session)
        }
        return nextHostID
    }

    // MARK: - Offline Queue & CloudKit Shot Upload

    func enqueueOrUploadPhoto(
        photo: ScrapPhoto,
        session: CaptureSession
    ) async {
        updateQueuedCount()
        guard isOnline else {
            photo.isSyncedToCloud = false
            try? modelContext.save()
            updateQueuedCount()
            return
        }

        let uploaded = await uploadPhotoRecord(photo: photo)
        photo.isSyncedToCloud = uploaded
        try? modelContext.save()
        updateQueuedCount()
    }

    func syncPendingOfflinePhotos() async {
        guard isOnline else { return }
        let descriptor = FetchDescriptor<ScrapPhoto>(
            predicate: #Predicate { !$0.isSyncedToCloud }
        )
        guard let pending = try? modelContext.fetch(descriptor), !pending.isEmpty else {
            queuedOfflineCount = 0
            return
        }

        for photo in pending {
            let ok = await uploadPhotoRecord(photo: photo)
            if ok {
                photo.isSyncedToCloud = true
            }
        }
        try? modelContext.save()
        updateQueuedCount()
    }

    func updateQueuedCount() {
        let descriptor = FetchDescriptor<ScrapPhoto>(
            predicate: #Predicate { !$0.isSyncedToCloud }
        )
        queuedOfflineCount = (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// Public `RollShot`: random UUID name and a single encrypted asset, no readable fields (change 012).
    nonisolated static func publicShotRecord(shotID: UUID, payloadURL: URL) -> CKRecord {
        let record = CKRecord(recordType: "RollShot", recordID: CKRecord.ID(recordName: shotID.uuidString))
        record["payload"] = CKAsset(fileURL: payloadURL)
        return record
    }

    /// Change 012: the shot goes to the public database as one encrypted blob with a random name
    /// (`RollShot`, field `payload`), and a `RollShotRef` goes into the members-only room zone as its index.
    private func uploadPhotoRecord(photo: ScrapPhoto) async -> Bool {
        let sessionID = photo.sourceSessionID
        let descriptor = FetchDescriptor<CaptureSession>(predicate: #Predicate { $0.id == sessionID })
        guard let session = try? modelContext.fetch(descriptor).first,
              session.ckRecordName != nil,
              let key = session.rollKey else {
            // Not a CloudKit room (no iCloud, Simulator): nothing to upload.
            return true
        }
        let payload = RollShotPayload(
            shotID: photo.id,
            sessionID: sessionID,
            authorID: photo.authorID,
            authorName: photo.authorName,
            caption: photo.caption,
            timestamp: photo.timestamp,
            photo: photo.imageData,
            livePhotoMovie: photo.livePhotoMovieData
        )
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        do {
            try RollShotCrypto.seal(payload, key: key).write(to: fileURL)

            let shot = Self.publicShotRecord(shotID: photo.id, payloadURL: fileURL)
            _ = try await CKContainer.default().publicCloudDatabase
                .modifyRecords(saving: [shot], deleting: [], savePolicy: .allKeys)

            let location = roomLocation(for: session)
            let ref = CKRecord(
                recordType: "RollShotRef",
                recordID: CKRecord.ID(recordName: "ShotRef-\(photo.id.uuidString)", zoneID: location.zoneID)
            )
            ref["shotRecordName"] = photo.id.uuidString
            ref["authorID"] = photo.authorID
            _ = try await location.database(in: CKContainer.default())
                .modifyRecords(saving: [ref], deleting: [], savePolicy: .allKeys)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Live Polling / Subscription Refresh During Active Session

    func startLiveSessionPolling(
        session: CaptureSession,
        onSessionEnded: @escaping @MainActor () -> Void
    ) {
        stopLiveSessionPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncPendingOfflinePhotos()
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.isOnline, session.ckRecordName != nil else { return }
                let location = self.roomLocation(for: session)
                if let record = try? await location.database(in: CKContainer.default()).record(for: location.sessionRecordID) {
                    if let remoteUsed = record["slotsUsed"] as? Int, remoteUsed > session.slotsUsed {
                        session.slotsUsed = remoteUsed
                    }
                    if let remoteHost = record["hostUserID"] as? String {
                        session.hostUserID = remoteHost
                    }
                    if let remoteStatus = record["statusRaw"] as? String,
                       remoteStatus == SessionStatus.ended.rawValue || session.slotsUsed >= session.rollSize {
                        session.status = .ended
                        session.endTime = .now
                        onSessionEnded()
                    }
                }
            }
        }
    }

    func stopLiveSessionPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

enum RollSessionError: LocalizedError {
    case rollAlreadyEnded
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .rollAlreadyEnded:
            return "This roll has already ended. Invite links and codes stay valid only until the roll ends."
        case .invalidCode:
            return "Please enter a valid 6-character roll code."
        }
    }
}
