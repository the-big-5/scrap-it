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
                    await self.syncPendingOfflinePhotos()
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
        guard isOnline else {
            print("⚠️ [CloudKitSessionService] publishSessionToCloudKit skipped: isOnline=false")
            return
        }
        guard session.ckRecordName != nil else {
            print("⚠️ [CloudKitSessionService] publishSessionToCloudKit skipped: ckRecordName=nil")
            return
        }
        let location = roomLocation(for: session)
        let database = location.database(in: CKContainer.app)
        do {
            let record = try await database.record(for: location.sessionRecordID)
            record["statusRaw"] = session.statusRaw as CKRecordValue
            record["hostUserID"] = session.hostUserID as CKRecordValue
            record["startTime"] = session.startTime as CKRecordValue
            if let endTime = session.endTime {
                record["endTime"] = endTime as CKRecordValue
            }
            try await database.save(record)
            print("✅ [CloudKitSessionService] publishSessionToCloudKit saved: status=\(session.statusRaw), roll=\(session.rollCode)")
        } catch {
            print("🚨 [CloudKitSessionService] publishSessionToCloudKit failed: \(error)")
        }
    }

    /// Edit Roll (change 081): the host's new name, shots and filter, for everyone in the lobby.
    func publishRollDetails(session: CaptureSession) async {
        guard isOnline, session.ckRecordName != nil else { return }
        // Read before waiting on CloudKit: the roll can be deleted meanwhile.
        let name = session.name
        let rollSize = session.rollSize
        let filterRaw = session.filterRaw
        let location = roomLocation(for: session)
        let database = location.database(in: CKContainer.app)
        do {
            let record = try await database.record(for: location.sessionRecordID)
            record["name"] = name as CKRecordValue
            record["rollSize"] = rollSize as CKRecordValue
            record["filterRaw"] = filterRaw as CKRecordValue
            try await database.save(record)
        } catch {
            print("🚨 [CloudKitSessionService] publishRollDetails failed: \(error)")
        }
    }

    // MARK: - Atomic Slot Claim (First Write Wins on Last-Slot Race)

    func claimSlotAtomically(
        session: CaptureSession,
        simulateRaceOnLastSlot: Bool = false
    ) async -> SlotClaimResult {
        if simulateRaceOnLastSlot {
            session.slotsUsed = session.rollSize
            session.status = .ended
            session.endTime = .now
            return .rollAlreadyFinished
        }

        // Optimistic concurrency via CloudKit CKModifyRecordsOperation (.ifServerRecordUnchanged)
        if isOnline, session.ckRecordName != nil {
            let location = roomLocation(for: session)
            let recordID = location.sessionRecordID
            let db = location.database(in: CKContainer.app)

            let maxRetries = 4
            for attempt in 1...maxRetries {
                guard let serverRecord = try? await db.record(for: recordID) else {
                    if attempt < maxRetries {
                        try? await Task.sleep(nanoseconds: 50_000_000 * UInt64(attempt))
                        continue
                    }
                    break
                }

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
                let willFinish = nextSlots >= serverRollSize
                if willFinish {
                    serverRecord["statusRaw"] = SessionStatus.ended.rawValue as CKRecordValue
                    serverRecord["endTime"] = Date.now as CKRecordValue
                }

                let conflictDetected = await saveRecordIfUnchanged(serverRecord, in: db)
                if !conflictDetected {
                    // Confirmed save to CloudKit
                    session.slotsUsed = nextSlots
                    if willFinish {
                        session.status = .ended
                        session.endTime = .now
                    }
                    return .claimed(newSlotsUsed: nextSlots, rollFinished: willFinish)
                }

                // Conflict occurred (.serverRecordChanged).
                // Another phone claimed a slot at the same time. Retry with latest server count.
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: 50_000_000 * UInt64(attempt))
                }
            }

            // Retries exhausted — perform final verification against latest server record
            if let latest = try? await db.record(for: recordID) {
                let latestUsed = (latest["slotsUsed"] as? Int) ?? session.slotsUsed
                let latestRollSize = (latest["rollSize"] as? Int) ?? session.rollSize
                let latestStatus = (latest["statusRaw"] as? String) ?? session.statusRaw
                if latestStatus == SessionStatus.ended.rawValue || latestUsed >= latestRollSize {
                    session.slotsUsed = latestRollSize
                    session.status = .ended
                    session.endTime = .now
                    return .rollAlreadyFinished
                }
            }
        }

        // Offline fallback or test mock path: slots are tracked locally
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
            op.qualityOfService = .userInitiated
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

    // MARK: - CloudKit Shot Upload (change 020: right after capture, long-lived)

    /// Shots being uploaded right now, shared by every service instance so a shot is never sent twice at once.
    private static var uploadingShotIDs: Set<UUID> = []
    /// Shots whose upload was picked up again after a relaunch: the parts (`RollShot`, `RollShotRef`) already saved
    /// and how many reattached operations are still running.
    private static var resumedShots: [UUID: (savedParts: Set<String>, runningOperations: Int)] = [:]

    private static let shotPart = "shot"
    private static let refPart = "ref"

    /// Uploads one shot in the background (change 020). Skipped while offline or when it is already being sent;
    /// the launch / reconnect retry picks it up later.
    @discardableResult
    func uploadShot(_ photo: ScrapPhoto) async -> Bool {
        guard isOnline, !photo.isDeleted, !photo.isSyncedToCloud,
              !Self.uploadingShotIDs.contains(photo.id) else { return false }
        let shotID = photo.id
        Self.uploadingShotIDs.insert(shotID)
        let ok = await uploadPhotoRecord(photo: photo)
        Self.uploadingShotIDs.remove(shotID)
        guard ok, !photo.isDeleted else { return false }
        photo.isSyncedToCloud = true
        try? modelContext.save()
        updateQueuedCount()
        return true
    }

    /// End Roll: uploads the shots that are still on this phone only, except `excluding`
    /// (claim not confirmed yet or Live Photo movie still encoding; those upload when ready).
    @discardableResult
    func uploadPendingPhotos(for session: CaptureSession, excluding: Set<UUID> = []) async -> Int {
        guard isOnline else {
            print("⚠️ [CloudKitSessionService] uploadPendingPhotos skipped: offline")
            return 0
        }
        let targetSessionID = session.id
        let descriptor = FetchDescriptor<ScrapPhoto>(
            predicate: #Predicate { $0.sourceSessionID == targetSessionID && !$0.isSyncedToCloud }
        )
        let pending = ((try? modelContext.fetch(descriptor)) ?? []).filter { !excluding.contains($0.id) }
        guard !pending.isEmpty else { return 0 }
        guard session.ckRecordName != nil else {
            // Not a CloudKit room (no iCloud, Simulator): nothing to upload.
            pending.forEach { $0.isSyncedToCloud = true }
            try? modelContext.save()
            return pending.count
        }
        print("🚀 [CloudKitSessionService] uploadPendingPhotos: uploading \(pending.count) photos for session \(session.rollCode)...")
        return await uploadAll(pending)
    }

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

    /// Launch and back online (change 020): uploads every shot not in CloudKit yet, from live and ended rolls.
    func syncPendingOfflinePhotos() async {
        guard isOnline else { return }
        let descriptor = FetchDescriptor<ScrapPhoto>(
            predicate: #Predicate { !$0.isSyncedToCloud }
        )
        let pending = (try? modelContext.fetch(descriptor)) ?? []
        await uploadAll(pending)
        updateQueuedCount()
    }

    /// On launch: picks up long-lived uploads that kept running while the app was closed (change 020),
    /// then uploads whatever is still missing.
    func resumeShotUploads() async {
        let container = CKContainer.app
        let operationIDs: [CKOperation.ID] = await withCheckedContinuation { continuation in
            container.fetchAllLongLivedOperationIDs { ids, _ in
                continuation.resume(returning: ids ?? [])
            }
        }
        for id in operationIDs {
            let operation: CKOperation? = await withCheckedContinuation { continuation in
                container.fetchLongLivedOperation(withID: id) { operation, _ in
                    continuation.resume(returning: operation)
                }
            }
            guard let modify = operation as? CKModifyRecordsOperation,
                  let shotID = Self.shotID(of: modify) else { continue }
            Self.uploadingShotIDs.insert(shotID)
            var resumed = Self.resumedShots[shotID] ?? (savedParts: [], runningOperations: 0)
            resumed.runningOperations += 1
            Self.resumedShots[shotID] = resumed
            let part = Self.part(of: modify)
            // Holds the service until the operation finishes (the launch instance is not kept anywhere else).
            modify.modifyRecordsResultBlock = { result in
                let saved = (try? result.get()) != nil
                Task { @MainActor in
                    self.resumedOperationFinished(shotID: shotID, part: part, saved: saved)
                }
            }
            container.add(modify)
        }
        await syncPendingOfflinePhotos()
    }

    func updateQueuedCount() {
        let sessionDesc = FetchDescriptor<CaptureSession>(
            predicate: #Predicate { $0.statusRaw == "ended" }
        )
        guard let endedSessions = try? modelContext.fetch(sessionDesc) else {
            queuedOfflineCount = 0
            return
        }
        let endedIDs = Set(endedSessions.map(\.id))
        let descriptor = FetchDescriptor<ScrapPhoto>(
            predicate: #Predicate { !$0.isSyncedToCloud }
        )
        guard let pending = try? modelContext.fetch(descriptor) else {
            queuedOfflineCount = 0
            return
        }
        queuedOfflineCount = pending.filter { endedIDs.contains($0.sourceSessionID) }.count
    }

    /// Public `RollShot`: random UUID name and a single encrypted asset, no readable fields (change 012).
    nonisolated static func publicShotRecord(shotID: UUID, payloadURL: URL) -> CKRecord {
        let record = CKRecord(recordType: "RollShot", recordID: CKRecord.ID(recordName: shotID.uuidString))
        record["payload"] = CKAsset(fileURL: payloadURL)
        return record
    }

    /// Where the encrypted payload waits until its long-lived save finishes (kept across app launches).
    nonisolated static func pendingPayloadURL(shotID: UUID) -> URL {
        URL.applicationSupportDirectory
            .appending(path: "PendingShots", directoryHint: .isDirectory)
            .appending(path: "\(shotID.uuidString).bin")
    }

    /// Uploads the shots at the same time; returns how many were uploaded.
    @discardableResult
    private func uploadAll(_ photos: [ScrapPhoto]) async -> Int {
        await withTaskGroup(of: Bool.self) { group in
            for photo in photos {
                group.addTask { @MainActor in
                    await self.uploadShot(photo)
                }
            }
            var uploaded = 0
            for await ok in group where ok {
                uploaded += 1
            }
            return uploaded
        }
    }

    private func resumedOperationFinished(shotID: UUID, part: String?, saved: Bool) {
        guard var resumed = Self.resumedShots[shotID] else { return }
        resumed.runningOperations -= 1
        if saved, let part {
            resumed.savedParts.insert(part)
            if part == Self.shotPart {
                try? FileManager.default.removeItem(at: Self.pendingPayloadURL(shotID: shotID))
            }
        }
        guard resumed.runningOperations <= 0 else {
            Self.resumedShots[shotID] = resumed
            return
        }
        Self.resumedShots[shotID] = nil
        Self.uploadingShotIDs.remove(shotID)
        let descriptor = FetchDescriptor<ScrapPhoto>(predicate: #Predicate { $0.id == shotID })
        guard let photo = try? modelContext.fetch(descriptor).first else { return }
        if resumed.savedParts == [Self.shotPart, Self.refPart] {
            photo.isSyncedToCloud = true
            try? modelContext.save()
            updateQueuedCount()
        } else {
            // A part was not saved while the app was closed: send the shot again (same record names).
            Task { await uploadShot(photo) }
        }
    }

    /// Shot ID of a `RollShot` (record name = shot ID) or `RollShotRef` (`ShotRef-<shot ID>`) save.
    private static func shotID(of operation: CKModifyRecordsOperation) -> UUID? {
        guard let name = operation.recordsToSave?.first?.recordID.recordName else { return nil }
        return UUID(uuidString: name.hasPrefix("ShotRef-") ? String(name.dropFirst("ShotRef-".count)) : name)
    }

    private static func part(of operation: CKModifyRecordsOperation) -> String? {
        switch operation.recordsToSave?.first?.recordType {
        case "RollShot": shotPart
        case "RollShotRef": refPart
        default: nil
        }
    }

    /// Change 012: the shot goes to the public database as one encrypted blob with a random name
    /// (`RollShot`, field `payload`), and a `RollShotRef` goes into the members-only room zone as its index.
    /// Change 020: both saves are long-lived, so the system finishes them even when the app is closed.
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
        let fileURL = Self.pendingPayloadURL(shotID: photo.id)
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try RollShotCrypto.seal(payload, key: key).write(to: fileURL)
        } catch {
            print("🚨 [CloudKitSessionService] uploadPhotoRecord could not write payload for \(photo.id.uuidString): \(error)")
            return false
        }

        let shot = Self.publicShotRecord(shotID: photo.id, payloadURL: fileURL)
        let location = roomLocation(for: session)
        let ref = CKRecord(
            recordType: "RollShotRef",
            recordID: CKRecord.ID(recordName: "ShotRef-\(photo.id.uuidString)", zoneID: location.zoneID)
        )
        ref["shotRecordName"] = photo.id.uuidString
        ref["authorID"] = photo.authorID

        async let shotSaved = Self.saveLongLived(shot, in: CKContainer.app.publicCloudDatabase)
        async let refSaved = Self.saveLongLived(ref, in: location.database(in: CKContainer.app))
        let (shotOK, refOK) = await (shotSaved, refSaved)
        if shotOK {
            try? FileManager.default.removeItem(at: fileURL)
        }
        if shotOK && refOK {
            print("📸 [CloudKitSessionService] Uploaded shot \(photo.id.uuidString) to public DB and zone ref to \(location.zoneID.zoneName)")
        } else {
            print("🚨 [CloudKitSessionService] uploadPhotoRecord failed for shot \(photo.id.uuidString): shot=\(shotOK) ref=\(refOK)")
        }
        return shotOK && refOK
    }

    /// One long-lived save (keeps running in the system after the app is closed or suspended).
    private static func saveLongLived(_ record: CKRecord, in database: CKDatabase) async -> Bool {
        await withCheckedContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.configuration.isLongLived = true
            operation.qualityOfService = .utility
            operation.modifyRecordsResultBlock = { result in
                if case .failure(let error) = result {
                    print("🚨 [CloudKitSessionService] long-lived save \(record.recordID.recordName) failed: \(error)")
                }
                continuation.resume(returning: (try? result.get()) != nil)
            }
            database.add(operation)
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
                guard let self else { return }
                guard self.isOnline, session.ckRecordName != nil else { return }
                let location = self.roomLocation(for: session)
                if let record = try? await location.database(in: CKContainer.app).record(for: location.sessionRecordID) {
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

    var errorDescription: String? {
        switch self {
        case .rollAlreadyEnded:
            return "This roll has already ended. Invite links and codes stay valid only until the roll ends."
        }
    }
}
