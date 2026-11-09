import Foundation
import OSLog
import SwiftData

/// Restores and completes scrapbooks from CloudKit (change 012): for every finished roll the user owns or
/// joined, downloads the encrypted public shots listed in the room, decrypts them with the roll key and
/// rebuilds the local `Scrapbook` and `ScrapPhoto`s (Live Photo movies included). Shots already on the
/// phone are skipped, so it is safe to run on every launch and after a roll ends (others' photos arrive).
final class ScrapbookArchiveSync {
    private let modelContext: ModelContext
    private let roomService: any RollRoomServicing
    private let deletedScrapbooks: DeletedScrapbookList
    private let log = Logger(subsystem: "ScrapIt", category: "ScrapbookArchive")
    private var isRunning = false

    init(
        modelContext: ModelContext,
        roomService: any RollRoomServicing,
        deletedScrapbooks: DeletedScrapbookList = .standard
    ) {
        self.modelContext = modelContext
        self.roomService = roomService
        self.deletedScrapbooks = deletedScrapbooks
    }

    /// Fast-path sync for a specific roll that just ended, avoiding scanning all historical rooms.
    @discardableResult
    func syncRoom(for session: CaptureSession) async -> Int {
        guard !deletedScrapbooks.contains(session.id) else { return 0 }
        guard let key = session.rollKey else {
            print("⚠️ [ScrapbookArchiveSync] syncRoom: session \(session.rollCode) has no rollKey")
            return 0
        }
        print("🔄 [ScrapbookArchiveSync] Fast-path syncing room \(session.rollCode)...")
        do {
            let room = try await roomService.fetchRoom(code: session.rollCode, zoneOwnerName: session.ckZoneOwnerName)
            print("📦 [ScrapbookArchiveSync] Fast-path fetched room \(room.rollCode): status=\(room.statusRaw), remoteShots=\(room.shotRecordNames.count)")
            let added = await restore(room, key: key)
            try? modelContext.save()
            print("✅ [ScrapbookArchiveSync] Fast-path sync for \(session.rollCode) finished. Added \(added) photos.")
            return added
        } catch {
            print("🚨 [ScrapbookArchiveSync] Fast-path fetchRoom \(session.rollCode) failed: \(error)")
            return await run()
        }
    }

    /// Returns how many photos were added across all ended rooms.
    @discardableResult
    func run() async -> Int {
        guard !isRunning else { return 0 }
        isRunning = true
        defer { isRunning = false }

        print("🔄 [ScrapbookArchiveSync] Starting archive sync...")
        let rooms: [RoomSnapshot]
        do {
            rooms = try await roomService.listRooms()
            print("🔄 [ScrapbookArchiveSync] listRooms found \(rooms.count) room(s)")
        } catch {
            print("🚨 [ScrapbookArchiveSync] listRooms failed: \(error)")
            log.error("listRooms failed: \(String(describing: error), privacy: .public)")
            return 0
        }

        var added = 0
        // Scrapbooks the user deleted on this device are not brought back (change 013).
        for room in rooms {
            print("📦 [ScrapbookArchiveSync] Room \(room.rollCode): status=\(room.statusRaw), shots=\(room.shotRecordNames.count), hasKey=\(room.rollKey != nil)")
            guard room.statusRaw == SessionStatus.ended.rawValue && !deletedScrapbooks.contains(room.sessionID) else {
                continue
            }
            guard let key = room.rollKey else {
                print("⚠️ [ScrapbookArchiveSync] Room \(room.rollCode) has no rollKey!")
                continue
            }
            added += await restore(room, key: key)
        }
        try? modelContext.save()
        print("✅ [ScrapbookArchiveSync] Archive sync finished. Total added photos: \(added)")
        return added
    }

    private func restore(_ room: RoomSnapshot, key: Data) async -> Int {
        let session = localSession(for: room, key: key)
        let scrapbook = localScrapbook(for: room, session: session)

        let sessionID = room.sessionID
        let existing = Set(
            ((try? modelContext.fetch(FetchDescriptor<ScrapPhoto>(predicate: #Predicate { $0.sourceSessionID == sessionID }))) ?? [])
                .map(\.id)
        )

        var added = 0
        print("📦 [ScrapbookArchiveSync] Restoring room \(room.rollCode) with \(room.shotRecordNames.count) shots (already have \(existing.count) local)")
        for name in room.shotRecordNames {
            guard let id = UUID(uuidString: name), !existing.contains(id) else {
                print("ℹ️ [ScrapbookArchiveSync] Shot \(name) already in local store; skipping")
                continue
            }
            do {
                let sealed = try await roomService.downloadShotPayload(recordName: name)
                let payload = try RollShotCrypto.open(sealed, key: key)
                let photo = ScrapPhoto(
                    id: payload.shotID,
                    imageData: payload.photo,
                    livePhotoMovieData: payload.livePhotoMovie,
                    caption: payload.caption,
                    authorID: payload.authorID,
                    authorName: payload.authorName,
                    timestamp: payload.timestamp,
                    sourceSessionID: payload.sessionID,
                    isSyncedToCloud: true,
                    scrapbook: scrapbook
                )
                modelContext.insert(photo)
                scrapbook.photos = (scrapbook.photos ?? []) + [photo]
                added += 1
                print("✅ [ScrapbookArchiveSync] Restored shot \(name) from \(payload.authorName)")
            } catch {
                print("🚨 [ScrapbookArchiveSync] Shot \(name) not restored: \(error)")
                log.error("Shot \(name, privacy: .public) not restored: \(String(describing: error), privacy: .public)")
            }
        }

        if scrapbook.coverPhotoData == nil {
            scrapbook.coverPhotoData = (scrapbook.photos ?? []).min { $0.timestamp < $1.timestamp }?.imageData
        }
        return added
    }

    private func localSession(for room: RoomSnapshot, key: Data) -> CaptureSession {
        let id = room.sessionID
        if let existing = try? modelContext.fetch(FetchDescriptor<CaptureSession>(predicate: #Predicate { $0.id == id })).first {
            if existing.rollKey == nil { existing.rollKey = key }
            return existing
        }
        let session = CaptureSession(
            id: room.sessionID,
            name: room.name,
            rollCode: room.rollCode,
            ckRecordName: RollRoomLocation.sessionRecordName,
            hostUserID: room.hostUserID,
            participantIDs: room.participants.map(\.userID),
            participantNames: room.participants.map(\.name),
            rollSize: room.rollSize,
            slotsUsed: room.slotsUsed,
            filter: RollFilter(rawValue: room.filterRaw) ?? .colorPrint200,
            status: .ended,
            endTime: room.endTime
        )
        session.ckZoneOwnerName = room.zoneOwnerName
        session.rollKey = key
        modelContext.insert(session)
        return session
    }

    private func localScrapbook(for room: RoomSnapshot, session: CaptureSession) -> Scrapbook {
        let id = room.sessionID
        if let existing = try? modelContext.fetch(FetchDescriptor<Scrapbook>(predicate: #Predicate { $0.sourceSessionID == id })).first {
            return existing
        }
        let scrapbook = Scrapbook(
            title: room.name,
            createdDate: room.endTime ?? .now,
            memberIDs: room.participants.map(\.userID),
            memberNames: room.participants.map(\.name),
            sourceSessionID: room.sessionID
        )
        modelContext.insert(scrapbook)
        session.createdScrapbookID = scrapbook.id
        return scrapbook
    }
}
