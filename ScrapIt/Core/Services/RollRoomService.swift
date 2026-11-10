import CloudKit
import Foundation
import OSLog

/// One person in a roll room.
struct RoomParticipant: Equatable, Identifiable, Sendable {
    let userID: String
    let name: String
    var avatarData: Data? = nil

    var id: String { userID }
}

/// What the lobby needs to know about a room, read from CloudKit.
struct RoomSnapshot: Equatable, Sendable {
    var sessionID: UUID
    var rollCode: String
    var name: String
    var hostUserID: String
    var rollSize: Int
    var slotsUsed: Int
    var filterRaw: String
    var statusRaw: String
    var participants: [RoomParticipant]
    /// iCloud share link (`https://www.icloud.com/share/…`), the invite link.
    var shareURL: URL?
    /// Owner of the room's zone. `nil` when this device's user owns it (the host).
    var zoneOwnerName: String?
    /// AES key for the roll's encrypted public shots (change 012).
    var rollKey: Data? = nil
    /// Public `RollShot` record names listed in the room (members-only index, change 012).
    var shotRecordNames: [String] = []
    var endTime: Date? = nil
}

/// Everything the host knows when creating a room.
struct RoomDraft: Equatable, Sendable {
    var sessionID: UUID
    var rollCode: String
    var name: String
    var rollSize: Int
    var filterRaw: String
    var host: RoomParticipant
    var rollKey: Data? = nil
}

enum RoomError: Error, Equatable {
    case notFound
    case ended
    case offline
    /// The host removed this user from the room.
    case removed
    /// The host deleted the room.
    case deleted
    /// iCloud is not available (not signed in, or CloudKit failed).
    case unavailable
}

/// Room operations (change 011). The live implementation uses CloudKit sharing; tests use a fake.
protocol RollRoomServicing: AnyObject {
    /// Raw description of the last CloudKit failure, for DEBUG diagnosis.
    var lastErrorDescription: String? { get }
    func createRoom(_ draft: RoomDraft) async throws -> RoomSnapshot
    func joinRoom(code: String, as user: RoomParticipant) async throws -> RoomSnapshot
    func acceptShare(_ metadata: CKShare.Metadata, as user: RoomParticipant) async throws -> RoomSnapshot
    func fetchRoom(code: String, zoneOwnerName: String?) async throws -> RoomSnapshot
    func updateParticipant(_ user: RoomParticipant, inRoom code: String, zoneOwnerName: String?) async throws
    func removeParticipant(userID: String, fromRoom code: String) async throws
    func leaveRoom(code: String, zoneOwnerName: String, userID: String) async throws
    func deleteRoom(code: String) async throws
    /// Every room this user owns or joined, with key and shot index (change 012 restore).
    func listRooms() async throws -> [RoomSnapshot]
    /// Encrypted payload of one public `RollShot`.
    func downloadShotPayload(recordName: String) async throws -> Data
    /// Encrypted payloads of several public `RollShot`s, fetched together (change 020).
    func downloadShotPayloads(recordNames: [String]) async -> [String: Result<Data, Error>]
}

extension RollRoomServicing {
    /// One by one; the CloudKit service fetches them in parallel batches.
    func downloadShotPayloads(recordNames: [String]) async -> [String: Result<Data, Error>] {
        var payloads: [String: Result<Data, Error>] = [:]
        for name in recordNames {
            do {
                payloads[name] = .success(try await downloadShotPayload(recordName: name))
            } catch {
                payloads[name] = .failure(error)
            }
        }
        return payloads
    }
}

extension RollRoomServicing {
    func updateParticipant(_ user: RoomParticipant, inRoom code: String, zoneOwnerName: String?) async throws {}
}

extension Notification.Name {
    /// CloudKit pushed a change to a room this user is in (join, leave, remove, start, delete).
    static let rollRoomDidChange = Notification.Name("ScrapIt.rollRoomDidChange")
}

/// Where a room lives in CloudKit: a zone per roll in the host's private database,
/// reached by participants through their shared database.
nonisolated struct RollRoomLocation: Equatable, Sendable {
    static let sessionRecordName = "RollSession"

    let zoneID: CKRecordZone.ID
    let isOwner: Bool

    init(rollCode: String, zoneOwnerName: String?) {
        zoneID = CKRecordZone.ID(zoneName: "Roll-\(rollCode)", ownerName: zoneOwnerName ?? CKCurrentUserDefaultName)
        isOwner = zoneOwnerName == nil
    }

    var sessionRecordID: CKRecord.ID {
        CKRecord.ID(recordName: Self.sessionRecordName, zoneID: zoneID)
    }

    func participantRecordID(userID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "Participant-\(userID)", zoneID: zoneID)
    }

    func database(in container: CKContainer) -> CKDatabase {
        isOwner ? container.privateCloudDatabase : container.sharedCloudDatabase
    }

    /// Public-database record that maps a roll code to the share link.
    static func codeRecordID(rollCode: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "RollCode-\(rollCode)")
    }
}

/// CloudKit sharing implementation:
/// - host: private-database zone `Roll-<code>` with the `RollSession` record and a zone-wide `CKShare`
///   (anyone with the link can read and write), plus a public `RollCode-<code>` record (code → link)
/// - participant: accepts the share, then writes their own `RollParticipant` record in the shared zone
extension CKContainer {
    /// The CloudKit container for this app build: `iCloud.lepin.scrapit` for the team build,
    /// otherwise the default `iCloud.<bundle ID>` so other developers' builds use their own container.
    static var app: CKContainer {
        if Bundle.main.bundleIdentifier == "com.lepin.ScrapIt" {
            return CKContainer(identifier: "iCloud.lepin.scrapit")
        }
        return .default()
    }
}

final class CloudKitRollRoomService: RollRoomServicing {
    private let explicitContainer: CKContainer?
    private var container: CKContainer {
        explicitContainer ?? .app
    }
    private var subscriptionsSaved = false
    private let log = Logger(subsystem: "ScrapIt", category: "RollRoom")
    /// Raw CloudKit error of the last failed room creation (shown in DEBUG builds for diagnosis).
    private(set) var lastErrorDescription: String?
    /// Why the "own room" check failed last time (DEBUG diagnosis of the same-iCloud case).
    private var ownRoomFailure: String?

    init(container: CKContainer? = nil) {
        self.explicitContainer = container
    }

    // MARK: - Host

    func createRoom(_ draft: RoomDraft) async throws -> RoomSnapshot {
        let location = RollRoomLocation(rollCode: draft.rollCode, zoneOwnerName: nil)
        let database = container.privateCloudDatabase
        do {
            _ = try await database.save(CKRecordZone(zoneID: location.zoneID))
            log.debug("Room zone saved: \(location.zoneID.zoneName, privacy: .public)")

            let session = CKRecord(recordType: "RollSession", recordID: location.sessionRecordID)
            session["sessionID"] = draft.sessionID.uuidString
            session["name"] = draft.name
            session["rollCode"] = draft.rollCode
            session["hostUserID"] = draft.host.userID
            session["rollSize"] = draft.rollSize
            session["slotsUsed"] = 0
            session["filterRaw"] = draft.filterRaw
            session["statusRaw"] = SessionStatus.waiting.rawValue
            if let key = draft.rollKey {
                session["rollKey"] = key
            }

            let host = participantRecord(draft.host, location: location)

            let share = CKShare(recordZoneID: location.zoneID)
            share[CKShare.SystemFieldKey.title] = draft.name
            share.publicPermission = .readWrite

            // `.allKeys` overwrites records left by an earlier failed attempt, so "Try again" works.
            let results = try await database.modifyRecords(saving: [session, host, share], deleting: [], savePolicy: .allKeys)
            for (id, result) in results.saveResults {
                if case .failure(let error) = result {
                    log.error("Saving \(id.recordName, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                    throw error
                }
            }
            var shareURL = (try? results.saveResults[share.recordID]?.get() as? CKShare)?.url
            if shareURL == nil {
                // The URL is filled in by the server; read the share back if the save result did not carry it.
                shareURL = (try? await database.record(for: share.recordID) as? CKShare)?.url
            }
            guard let shareURL else {
                log.error("Share saved without a URL")
                throw RoomError.unavailable
            }

            // Roll code → link. If this fails the link still works; only joining by code would not.
            let code = CKRecord(recordType: "RollCode", recordID: RollRoomLocation.codeRecordID(rollCode: draft.rollCode))
            code["shareURL"] = shareURL.absoluteString
            code["name"] = draft.name
            code["hostUserID"] = draft.host.userID
            do {
                _ = try await container.publicCloudDatabase.modifyRecords(saving: [code], deleting: [], savePolicy: .allKeys)
            } catch {
                log.error("Saving roll code record failed: \(String(describing: error), privacy: .public)")
            }

            await saveSubscriptionsIfNeeded()
            return RoomSnapshot(
                sessionID: draft.sessionID,
                rollCode: draft.rollCode,
                name: draft.name,
                hostUserID: draft.host.userID,
                rollSize: draft.rollSize,
                slotsUsed: 0,
                filterRaw: draft.filterRaw,
                statusRaw: SessionStatus.waiting.rawValue,
                participants: [draft.host],
                shareURL: shareURL,
                zoneOwnerName: nil,
                rollKey: draft.rollKey
            )
        } catch {
            log.error("createRoom failed: \(String(describing: error), privacy: .public)")
            lastErrorDescription = String(describing: error)
            throw Self.roomError(from: error)
        }
    }

    func removeParticipant(userID: String, fromRoom code: String) async throws {
        let location = RollRoomLocation(rollCode: code, zoneOwnerName: nil)
        let database = container.privateCloudDatabase
        do {
            let records = try await zoneRecords(location: location, in: database)
            let participant = records.first {
                $0.recordType == "RollParticipant" && ($0["userID"] as? String) == userID
            }
            if let participant {
                _ = try await database.deleteRecord(withID: participant.recordID)
            }
            // Take them out of the share too, so they lose access to the room.
            let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: location.zoneID)
            if let share = try await database.record(for: shareID) as? CKShare,
               let creator = participant?.creatorUserRecordID,
               let shareParticipant = share.participants.first(where: { $0.userIdentity.userRecordID == creator }) {
                share.removeParticipant(shareParticipant)
                _ = try await database.save(share)
            }
        } catch {
            throw Self.roomError(from: error)
        }
    }

    func deleteRoom(code: String) async throws {
        let location = RollRoomLocation(rollCode: code, zoneOwnerName: nil)
        do {
            _ = try? await container.publicCloudDatabase.deleteRecord(withID: RollRoomLocation.codeRecordID(rollCode: code))
            // Deleting the zone also deletes its share, so participants lose the room.
            _ = try await container.privateCloudDatabase.deleteRecordZone(withID: location.zoneID)
        } catch {
            throw Self.roomError(from: error)
        }
    }

    // MARK: - Participant

    func joinRoom(code: String, as user: RoomParticipant) async throws -> RoomSnapshot {
        if let own = await ownRoom(code: code) {
            return await syncParticipantIfNeeded(user, in: own)
        }
        do {
            let codeRecord = try await container.publicCloudDatabase.record(for: RollRoomLocation.codeRecordID(rollCode: code))
            guard let link = codeRecord["shareURL"] as? String, let url = URL(string: link) else {
                throw RoomError.notFound
            }
            let metadata = try await container.shareMetadata(for: url)
            return try await acceptShare(metadata, as: user)
        } catch {
            log.error("joinRoom failed: \(String(describing: error), privacy: .public)")
            lastErrorDescription = Self.detail(error, ownRoomFailure: ownRoomFailure, previous: lastErrorDescription)
            throw Self.roomError(from: error)
        }
    }

    func acceptShare(_ metadata: CKShare.Metadata, as user: RoomParticipant) async throws -> RoomSnapshot {
        let code = String(metadata.share.recordID.zoneID.zoneName.dropFirst("Roll-".count))
        if let own = await ownRoom(code: code) {
            return await syncParticipantIfNeeded(user, in: own)
        }
        do {
            let zoneID = metadata.share.recordID.zoneID
            // The host opening their own link: the room is in their private database.
            let isOwner = metadata.participantRole == .owner
            if !isOwner {
                _ = try await container.accept(metadata)
            }
            let rollCode = String(zoneID.zoneName.dropFirst("Roll-".count))
            let location = RollRoomLocation(rollCode: rollCode, zoneOwnerName: isOwner ? nil : zoneID.ownerName)
            let snapshot = try await fetchRoom(code: rollCode, zoneOwnerName: location.isOwner ? nil : zoneID.ownerName)
            if snapshot.statusRaw == SessionStatus.ended.rawValue || snapshot.slotsUsed >= snapshot.rollSize {
                throw RoomError.ended
            }
            var joined = snapshot
            if let index = joined.participants.firstIndex(where: { $0.userID == user.userID }) {
                if joined.participants[index].name != user.name || joined.participants[index].avatarData != user.avatarData {
                    try? await updateParticipant(user, inRoom: rollCode, zoneOwnerName: location.isOwner ? nil : zoneID.ownerName)
                    joined.participants[index] = user
                }
            } else {
                _ = try await location.database(in: container).save(participantRecord(user, location: location))
                joined.participants.append(user)
            }
            await saveSubscriptionsIfNeeded()
            return joined
        } catch {
            log.error("acceptShare failed: \(String(describing: error), privacy: .public)")
            lastErrorDescription = Self.detail(error, ownRoomFailure: ownRoomFailure, previous: lastErrorDescription)
            throw Self.roomError(from: error)
        }
    }

    func leaveRoom(code: String, zoneOwnerName: String, userID: String) async throws {
        let location = RollRoomLocation(rollCode: code, zoneOwnerName: zoneOwnerName)
        let database = container.sharedCloudDatabase
        do {
            _ = try? await database.deleteRecord(withID: location.participantRecordID(userID: userID))
            // Deleting a shared zone from the shared database leaves the share.
            _ = try await database.deleteRecordZone(withID: location.zoneID)
        } catch {
            throw Self.roomError(from: error)
        }
    }

    // MARK: - Both

    func fetchRoom(code: String, zoneOwnerName: String?) async throws -> RoomSnapshot {
        let location = RollRoomLocation(rollCode: code, zoneOwnerName: zoneOwnerName)
        let database = location.database(in: container)
        do {
            let records = try await zoneRecords(location: location, in: database)
            guard let session = records.first(where: { $0.recordType == "RollSession" }) else {
                throw RoomError.deleted
            }
            let participants = records
                .filter { $0.recordType == "RollParticipant" }
                .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
                .compactMap { record -> RoomParticipant? in
                    guard let id = record["userID"] as? String else { return nil }
                    return RoomParticipant(
                        userID: id,
                        name: (record["name"] as? String) ?? "Friend",
                        avatarData: record["avatarData"] as? Data
                    )
                }
            let share = records.first { $0 is CKShare } as? CKShare
            let shotRecordNames = records
                .filter { $0.recordType == "RollShotRef" }
                .compactMap { $0["shotRecordName"] as? String }
            return RoomSnapshot(
                sessionID: UUID(uuidString: (session["sessionID"] as? String) ?? "") ?? UUID(),
                rollCode: code,
                name: (session["name"] as? String) ?? "Roll",
                hostUserID: (session["hostUserID"] as? String) ?? "",
                rollSize: (session["rollSize"] as? Int) ?? 36,
                slotsUsed: (session["slotsUsed"] as? Int) ?? 0,
                filterRaw: (session["filterRaw"] as? String) ?? RollFilter.colorPrint200.rawValue,
                statusRaw: (session["statusRaw"] as? String) ?? SessionStatus.waiting.rawValue,
                participants: participants,
                shareURL: share?.url,
                zoneOwnerName: zoneOwnerName,
                rollKey: session["rollKey"] as? Data,
                shotRecordNames: shotRecordNames,
                endTime: session["endTime"] as? Date
            )
        } catch let error as RoomError {
            throw error
        } catch {
            log.error("fetchRoom \(code, privacy: .public) (owner: \(location.isOwner)) failed: \(String(describing: error), privacy: .public)")
            lastErrorDescription = String(describing: error)
            let mapped = Self.roomError(from: error)
            guard mapped == .deleted, !location.isOwner else { throw mapped }
            // Lost access to the shared zone: removed by the host if the room still exists, else deleted.
            let stillExists = (try? await container.publicCloudDatabase.record(for: RollRoomLocation.codeRecordID(rollCode: code))) != nil
            throw stillExists ? RoomError.removed : RoomError.deleted
        }
    }

    // MARK: - Archive (change 012)

    func listRooms() async throws -> [RoomSnapshot] {
        var rooms: [RoomSnapshot] = []
        for (database, isOwn) in [(container.privateCloudDatabase, true), (container.sharedCloudDatabase, false)] {
            let zones: [CKRecordZone]
            do {
                zones = try await database.allRecordZones()
            } catch {
                log.error("listRooms (own: \(isOwn)) failed: \(String(describing: error), privacy: .public)")
                continue
            }
            for zone in zones where zone.zoneID.zoneName.hasPrefix("Roll-") {
                let code = String(zone.zoneID.zoneName.dropFirst("Roll-".count))
                var room = try? await fetchRoom(code: code, zoneOwnerName: isOwn ? nil : zone.zoneID.ownerName)
                if room == nil {
                    // Retry once on failure to recover from transient network drops
                    try? await Task.sleep(for: .milliseconds(600))
                    room = try? await fetchRoom(code: code, zoneOwnerName: isOwn ? nil : zone.zoneID.ownerName)
                }
                if let room {
                    rooms.append(room)
                }
            }
        }
        return rooms
    }

    func downloadShotPayload(recordName: String) async throws -> Data {
        let record = try await container.publicCloudDatabase.record(for: CKRecord.ID(recordName: recordName))
        guard let url = (record["payload"] as? CKAsset)?.fileURL else { throw RoomError.notFound }
        return try Data(contentsOf: url)
    }

    /// Change 020: friends' shots in batches of `shotBatchSize`, the batches downloaded at the same time.
    func downloadShotPayloads(recordNames: [String]) async -> [String: Result<Data, Error>] {
        let database = container.publicCloudDatabase
        let batches = stride(from: 0, to: recordNames.count, by: Self.shotBatchSize).map {
            Array(recordNames[$0..<min($0 + Self.shotBatchSize, recordNames.count)])
        }
        return await withTaskGroup(of: [String: Result<Data, Error>].self) { group in
            for batch in batches {
                group.addTask {
                    await Self.fetchShotBatch(batch, in: database)
                }
            }
            var payloads: [String: Result<Data, Error>] = [:]
            for await result in group {
                payloads.merge(result) { first, _ in first }
            }
            return payloads
        }
    }

    private static let shotBatchSize = 6

    nonisolated private static func fetchShotBatch(_ names: [String], in database: CKDatabase) async -> [String: Result<Data, Error>] {
        var payloads: [String: Result<Data, Error>] = [:]
        do {
            let records = try await database.records(for: names.map { CKRecord.ID(recordName: $0) })
            for (id, result) in records {
                payloads[id.recordName] = Result {
                    guard let url = (try result.get()["payload"] as? CKAsset)?.fileURL else { throw RoomError.notFound }
                    return try Data(contentsOf: url)
                }
            }
        } catch {
            for name in names {
                payloads[name] = .failure(error)
            }
        }
        return payloads
    }

    // MARK: - Helpers

    /// Same iCloud as the host (this device or another one): the room zone exists in this user's own
    /// private database, so open it there as the host. No join, no extra participant, no error.
    private func ownRoom(code: String) async -> RoomSnapshot? {
        ownRoomFailure = nil
        do {
            let room = try await fetchRoom(code: code, zoneOwnerName: nil)
            log.debug("Opening own room \(code, privacy: .public)")
            return room
        } catch {
            // Expected for anyone who is not the host; the detail helps when the host's own fetch fails.
            log.debug("Not an own room \(code, privacy: .public): \(String(describing: error), privacy: .public)")
            ownRoomFailure = lastErrorDescription
            return nil
        }
    }

    func updateParticipant(_ user: RoomParticipant, inRoom code: String, zoneOwnerName: String?) async throws {
        let location = RollRoomLocation(rollCode: code, zoneOwnerName: zoneOwnerName)
        let database = location.database(in: container)
        let record = participantRecord(user, location: location)
        let results = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        if case .failure(let error)? = results.saveResults[record.recordID] {
            throw error
        }
    }

    private func syncParticipantIfNeeded(_ user: RoomParticipant, in snapshot: RoomSnapshot) async -> RoomSnapshot {
        var updated = snapshot
        if let index = updated.participants.firstIndex(where: { $0.userID == user.userID }) {
            let existing = updated.participants[index]
            if existing.name != user.name || existing.avatarData != user.avatarData {
                try? await updateParticipant(user, inRoom: snapshot.rollCode, zoneOwnerName: snapshot.zoneOwnerName)
                updated.participants[index] = user
            }
        }
        return updated
    }

    private func participantRecord(_ user: RoomParticipant, location: RollRoomLocation) -> CKRecord {
        let record = CKRecord(recordType: "RollParticipant", recordID: location.participantRecordID(userID: user.userID))
        record["userID"] = user.userID
        record["name"] = user.name
        record["avatarData"] = user.avatarData
        return record
    }

    /// All records in the room zone (no query index needed) with automatic retry on network drops.
    private func zoneRecords(location: RollRoomLocation, in database: CKDatabase) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var token: CKServerChangeToken?
        var moreComing = true
        while moreComing {
            var lastError: (any Error)?
            var gotChanges = false
            for attempt in 1...3 {
                do {
                    let changes = try await database.recordZoneChanges(inZoneWith: location.zoneID, since: token)
                    for (_, result) in changes.modificationResultsByID {
                        if let modification = try? result.get() {
                            records.append(modification.record)
                        }
                    }
                    token = changes.changeToken
                    moreComing = changes.moreComing
                    gotChanges = true
                    break
                } catch {
                    lastError = error
                    let retryAfter = (error as? CKError)?.retryAfterSeconds ?? 1.0
                    if attempt < 3 {
                        try? await Task.sleep(for: .seconds(min(retryAfter, 2.0)))
                    }
                }
            }
            if !gotChanges {
                if let lastError { throw lastError }
                break
            }
        }
        return records
    }

    /// Silent pushes for any change in the user's rooms (owned and shared).
    private func saveSubscriptionsIfNeeded() async {
        guard !subscriptionsSaved else { return }
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        for (database, id) in [(container.privateCloudDatabase, "rooms-private"), (container.sharedCloudDatabase, "rooms-shared")] {
            let subscription = CKDatabaseSubscription(subscriptionID: id)
            subscription.notificationInfo = info
            _ = try? await database.save(subscription)
        }
        subscriptionsSaved = true
    }

    /// Raw error text for DEBUG: the CloudKit error (not our mapped `RoomError`), plus why the own-room check failed.
    private static func detail(_ error: Error, ownRoomFailure: String?, previous: String?) -> String {
        let raw = error is RoomError ? (previous ?? String(describing: error)) : String(describing: error)
        guard let ownRoomFailure else { return raw }
        return "own room: \(ownRoomFailure)\njoin: \(raw)"
    }

    static func roomError(from error: Error) -> RoomError {
        if let room = error as? RoomError { return room }
        guard let ck = error as? CKError else { return .unavailable }
        switch ck.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
            return .offline
        case .unknownItem:
            return .notFound
        case .zoneNotFound, .userDeletedZone, .permissionFailure, .participantMayNeedVerification:
            return .deleted
        case .notAuthenticated:
            return .unavailable
        default:
            return .unavailable
        }
    }
}
