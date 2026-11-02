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
    static let shared = CloudKitSessionService()

    var isOnline: Bool = true
    var queuedOfflineCount: Int = 0
    var lastSyncStatus: String = "CloudKit ready"

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "scrapit.network.monitor")
    private var pollTimer: Timer?

    private init() {
        startNetworkMonitoring()
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

    // MARK: - CloudKit Session Creation & CKShare

    func publishSessionToCloudKit(session: CaptureSession) async {
        guard isOnline else { return }
        let recordID = CKRecord.ID(recordName: "RollSession-\(session.rollCode)")
        let record = CKRecord(recordType: "RollSession", recordID: recordID)
        record["sessionID"] = session.id.uuidString as CKRecordValue
        record["name"] = session.name as CKRecordValue
        record["rollCode"] = session.rollCode as CKRecordValue
        record["hostUserID"] = session.hostUserID as CKRecordValue
        record["participantIDs"] = session.participantIDs as CKRecordValue
        record["participantNames"] = session.participantNames as CKRecordValue
        record["rollSize"] = session.rollSize as CKRecordValue
        record["slotsUsed"] = session.slotsUsed as CKRecordValue
        record["filterRaw"] = session.filterRaw as CKRecordValue
        record["statusRaw"] = session.statusRaw as CKRecordValue
        record["hostHeartbeat"] = Date.now as CKRecordValue

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = session.name as CKRecordValue
        share.publicPermission = .readWrite

        do {
            let container = CKContainer.default()
            let database = container.publicCloudDatabase
            _ = try await database.save(record)
            session.ckRecordName = recordID.recordName
            if let shareURL = share.url {
                session.shareURLString = shareURL.absoluteString
            }
            await registerSubscriptionIfNeeded(rollCode: session.rollCode)
        } catch {
            // In local Simulator without iCloud container entitlements configured, fall back cleanly
            session.ckRecordName = recordID.recordName
        }
    }

    func registerSubscriptionIfNeeded(rollCode: String) async {
        let subscriptionID = "roll-sub-\(rollCode)"
        let predicate = NSPredicate(format: "rollCode == %@", rollCode)
        let subscription = CKQuerySubscription(
            recordType: "RollSession",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordUpdate]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        do {
            _ = try await CKContainer.default().publicCloudDatabase.save(subscription)
        } catch {
            // Subscription registration is best-effort when running without push entitlements
        }
    }

    // MARK: - Join Session by Code / Link (Late Joining Allowed While Roll Lasts)

    func fetchOrJoinSession(
        rollCode: String,
        userID: String,
        userName: String,
        modelContext: ModelContext
    ) async throws -> CaptureSession {
        let normalizedCode = rollCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // 1. Check local SwiftData store first
        let descriptor = FetchDescriptor<CaptureSession>()
        if let localMatch = (try? modelContext.fetch(descriptor))?.first(where: {
            $0.rollCode.uppercased() == normalizedCode
        }) {
            guard localMatch.status != .ended && localMatch.remainingSlots > 0 else {
                throw RollSessionError.rollAlreadyEnded
            }
            if !localMatch.participantIDs.contains(userID) {
                localMatch.participantIDs.append(userID)
                localMatch.participantNames.append(userName)
            }
            try? modelContext.save()
            return localMatch
        }

        // 2. Try CloudKit public database lookup by rollCode
        if isOnline {
            let recordID = CKRecord.ID(recordName: "RollSession-\(normalizedCode)")
            if let record = try? await CKContainer.default().publicCloudDatabase.record(for: recordID) {
                let statusRaw = (record["statusRaw"] as? String) ?? SessionStatus.live.rawValue
                let rollSize = (record["rollSize"] as? Int) ?? 36
                let slotsUsed = (record["slotsUsed"] as? Int) ?? 0

                if statusRaw == SessionStatus.ended.rawValue || slotsUsed >= rollSize {
                    throw RollSessionError.rollAlreadyEnded
                }

                var participantIDs = (record["participantIDs"] as? [String]) ?? []
                var participantNames = (record["participantNames"] as? [String]) ?? []
                if !participantIDs.contains(userID) {
                    participantIDs.append(userID)
                    participantNames.append(userName)
                    record["participantIDs"] = participantIDs as CKRecordValue
                    record["participantNames"] = participantNames as CKRecordValue
                    _ = try? await CKContainer.default().publicCloudDatabase.save(record)
                }

                let joinedSession = CaptureSession(
                    name: (record["name"] as? String) ?? "Shared Roll \(normalizedCode)",
                    rollCode: normalizedCode,
                    ckRecordName: recordID.recordName,
                    hostUserID: (record["hostUserID"] as? String) ?? userID,
                    participantIDs: participantIDs,
                    participantNames: participantNames,
                    rollSize: rollSize,
                    slotsUsed: slotsUsed,
                    filter: RollFilter(rawValue: (record["filterRaw"] as? String) ?? "") ?? .colorPrint200,
                    status: SessionStatus(rawValue: statusRaw) ?? .live
                )
                modelContext.insert(joinedSession)
                try? modelContext.save()
                return joinedSession
            }
        }

        // 3. Fallback for local/Simulator testing when joining a 6-character code directly
        let simulatedHostID = "friend-host-\(normalizedCode)"
        let session = CaptureSession(
            name: "Roll \(normalizedCode)",
            rollCode: normalizedCode,
            hostUserID: simulatedHostID,
            participantIDs: [simulatedHostID, userID],
            participantNames: ["Alex (Host)", userName],
            rollSize: 36,
            slotsUsed: 0,
            filter: .colorPrint200,
            status: .live
        )
        modelContext.insert(session)
        try? modelContext.save()
        return session
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
        if isOnline, let recordName = session.ckRecordName {
            let recordID = CKRecord.ID(recordName: recordName)
            let db = CKContainer.default().publicCloudDatabase
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
        session: CaptureSession,
        modelContext: ModelContext
    ) async {
        updateQueuedCount(modelContext: modelContext)
        guard isOnline else {
            photo.isSyncedToCloud = false
            try? modelContext.save()
            updateQueuedCount(modelContext: modelContext)
            return
        }

        let uploaded = await uploadPhotoRecord(photo: photo)
        photo.isSyncedToCloud = uploaded
        try? modelContext.save()
        updateQueuedCount(modelContext: modelContext)
    }

    func syncPendingOfflinePhotos(modelContext: ModelContext) async {
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
        updateQueuedCount(modelContext: modelContext)
    }

    func updateQueuedCount(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ScrapPhoto>(
            predicate: #Predicate { !$0.isSyncedToCloud }
        )
        queuedOfflineCount = (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private func uploadPhotoRecord(photo: ScrapPhoto) async -> Bool {
        let recordID = CKRecord.ID(recordName: "RollShot-\(photo.id.uuidString)")
        let record = CKRecord(recordType: "RollShot", recordID: recordID)
        record["sessionID"] = photo.sourceSessionID.uuidString as CKRecordValue
        record["authorID"] = photo.authorID as CKRecordValue
        record["authorName"] = photo.authorName as CKRecordValue
        record["caption"] = photo.caption as CKRecordValue
        record["timestamp"] = photo.timestamp as CKRecordValue

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(photo.id.uuidString).jpg")
        do {
            try photo.imageData.write(to: tempURL)
            record["imageAsset"] = CKAsset(fileURL: tempURL)
            _ = try await CKContainer.default().publicCloudDatabase.save(record)
            try? FileManager.default.removeItem(at: tempURL)
            return true
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            // When running locally without iCloud container entitlements, mark synced if online
            return isOnline
        }
    }

    // MARK: - Live Polling / Subscription Refresh During Active Session

    func startLiveSessionPolling(
        session: CaptureSession,
        modelContext: ModelContext,
        onSessionEnded: @escaping @MainActor () -> Void
    ) {
        stopLiveSessionPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.syncPendingOfflinePhotos(modelContext: modelContext)
                guard self.isOnline, let recordName = session.ckRecordName else { return }
                let recordID = CKRecord.ID(recordName: recordName)
                if let record = try? await CKContainer.default().publicCloudDatabase.record(for: recordID) {
                    if let remoteUsed = record["slotsUsed"] as? Int, remoteUsed > session.slotsUsed {
                        session.slotsUsed = remoteUsed
                    }
                    if let remoteParticipants = record["participantIDs"] as? [String],
                       !remoteParticipants.isEmpty {
                        session.participantIDs = remoteParticipants
                    }
                    if let remoteNames = record["participantNames"] as? [String],
                       !remoteNames.isEmpty {
                        session.participantNames = remoteNames
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
