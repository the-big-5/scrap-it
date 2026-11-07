import CloudKit
import Foundation
import SwiftData
import Testing
@testable import ScrapIt

private final class ArchiveRoomService: RollRoomServicing {
    var lastErrorDescription: String?
    var rooms: [RoomSnapshot] = []
    var payloads: [String: Data] = [:]
    var downloads: [String] = []

    func createRoom(_ draft: RoomDraft) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func joinRoom(code: String, as user: RoomParticipant) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func acceptShare(_ metadata: CKShare.Metadata, as user: RoomParticipant) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func fetchRoom(code: String, zoneOwnerName: String?) async throws -> RoomSnapshot { throw RoomError.unavailable }
    func removeParticipant(userID: String, fromRoom code: String) async throws {}
    func leaveRoom(code: String, zoneOwnerName: String, userID: String) async throws {}
    func deleteRoom(code: String) async throws {}
    func listRooms() async throws -> [RoomSnapshot] { rooms }

    func downloadShotPayload(recordName: String) async throws -> Data {
        downloads.append(recordName)
        guard let data = payloads[recordName] else { throw RoomError.notFound }
        return data
    }
}

// MARK: - Encryption

struct RollShotCryptoTests {
    private let payload = RollShotPayload(
        shotID: UUID(), sessionID: UUID(), authorID: "host-1", authorName: "Nabiel Secret",
        caption: "sunset at the beach", timestamp: Date(timeIntervalSince1970: 1_000),
        photo: Data("JPEG-BYTES".utf8), livePhotoMovie: Data("MOV-BYTES".utf8)
    )

    @Test func sealedShotOpensWithTheRollKey() throws {
        let key = RollShotCrypto.newRollKey()
        let sealed = try RollShotCrypto.seal(payload, key: key)
        #expect(try RollShotCrypto.open(sealed, key: key) == payload)
    }

    @Test func wrongKeyCannotOpenTheShot() throws {
        let sealed = try RollShotCrypto.seal(payload, key: RollShotCrypto.newRollKey())
        #expect(throws: (any Error).self) {
            _ = try RollShotCrypto.open(sealed, key: RollShotCrypto.newRollKey())
        }
    }

    @Test func sealedShotHasNoReadableText() throws {
        let sealed = try RollShotCrypto.seal(payload, key: RollShotCrypto.newRollKey())
        let text = String(decoding: sealed, as: UTF8.self)
        for secret in ["Nabiel", "sunset", "host-1", "JPEG", "MOV"] {
            #expect(!text.contains(secret))
        }
    }

    @Test func rollKeysAreRandom256Bit() {
        let a = RollShotCrypto.newRollKey()
        #expect(a.count == 32)
        #expect(a != RollShotCrypto.newRollKey())
    }

    @Test func publicShotRecordHasARandomNameAndOnlyThePayload() {
        let id = UUID()
        let record = CloudKitSessionService.publicShotRecord(
            shotID: id, payloadURL: FileManager.default.temporaryDirectory.appendingPathComponent("x.bin")
        )
        #expect(record.recordID.recordName == id.uuidString)
        #expect(record.allKeys() == ["payload"])
    }
}

// MARK: - Restore

@MainActor
struct ScrapbookArchiveTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    private let service = ArchiveRoomService()
    private let key = RollShotCrypto.newRollKey()
    private let sessionID = UUID()

    init() throws {
        container = try ModelContainer(
            for: ScrapIt.schema,
            // Unique name: the test host app already uses the "default" and "Rolls" stores.
            configurations: ModelConfiguration(UUID().uuidString, schema: ScrapIt.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func addShot(author: String, movie: Data? = nil, at time: TimeInterval) throws -> UUID {
        let id = UUID()
        let payload = RollShotPayload(
            shotID: id, sessionID: sessionID, authorID: author, authorName: author.capitalized,
            caption: "", timestamp: Date(timeIntervalSince1970: time),
            photo: Data("photo-\(id)".utf8), livePhotoMovie: movie
        )
        service.payloads[id.uuidString] = try RollShotCrypto.seal(payload, key: key)
        return id
    }

    private func endedRoom(shots: [UUID], key: Data?) -> RoomSnapshot {
        RoomSnapshot(
            sessionID: sessionID, rollCode: "N4B13L", name: "Bali '27", hostUserID: "host-1",
            rollSize: 36, slotsUsed: shots.count, filterRaw: RollFilter.colorPrint200.rawValue,
            statusRaw: SessionStatus.ended.rawValue,
            participants: [RoomParticipant(userID: "host-1", name: "Nabiel"), RoomParticipant(userID: "guest-2", name: "Brian")],
            shareURL: nil, zoneOwnerName: "_owner", rollKey: key,
            shotRecordNames: shots.map(\.uuidString), endTime: Date(timeIntervalSince1970: 5_000)
        )
    }

    @Test func restoreRebuildsScrapbookAndPhotosIncludingLivePhotos() async throws {
        let first = try addShot(author: "host-1", movie: Data("mov".utf8), at: 100)
        let second = try addShot(author: "guest-2", at: 200)
        service.rooms = [endedRoom(shots: [second, first], key: key)]

        let added = await ScrapbookArchiveSync(modelContext: context, roomService: service).run()

        #expect(added == 2)
        let scrapbook = try #require(try context.fetch(FetchDescriptor<Scrapbook>()).first)
        #expect(scrapbook.title == "Bali '27")
        #expect(scrapbook.sourceSessionID == sessionID)
        #expect(scrapbook.memberIDs == ["host-1", "guest-2"])
        let photos = scrapbook.photos ?? []
        #expect(Set(photos.map(\.id)) == [first, second])
        #expect(photos.first { $0.id == first }?.livePhotoMovieData == Data("mov".utf8))
        #expect(scrapbook.coverPhotoData == photos.first { $0.id == first }?.imageData)
        let session = try #require(try context.fetch(FetchDescriptor<CaptureSession>()).first)
        #expect(session.status == .ended)
        #expect(session.rollKey == key)
        #expect(session.createdScrapbookID == scrapbook.id)
    }

    @Test func secondRunAddsNothing() async throws {
        let shot = try addShot(author: "host-1", at: 100)
        service.rooms = [endedRoom(shots: [shot], key: key)]
        let sync = ScrapbookArchiveSync(modelContext: context, roomService: service)

        await sync.run()
        let addedAgain = await sync.run()

        #expect(addedAgain == 0)
        #expect(service.downloads == [shot.uuidString])
        #expect(try context.fetch(FetchDescriptor<Scrapbook>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<ScrapPhoto>()).count == 1)
    }

    @Test func friendsPhotosArriveLaterInTheSameScrapbook() async throws {
        let mine = try addShot(author: "host-1", at: 100)
        service.rooms = [endedRoom(shots: [mine], key: key)]
        let sync = ScrapbookArchiveSync(modelContext: context, roomService: service)
        await sync.run()

        let theirs = try addShot(author: "guest-2", at: 200)
        service.rooms = [endedRoom(shots: [mine, theirs], key: key)]
        await sync.run()

        #expect(try context.fetch(FetchDescriptor<Scrapbook>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<ScrapPhoto>()).count == 2)
    }

    @Test func roomsWithoutAKeyOrNotEndedAreSkipped() async throws {
        let shot = try addShot(author: "host-1", at: 100)
        var live = endedRoom(shots: [shot], key: key)
        live.statusRaw = SessionStatus.live.rawValue
        service.rooms = [endedRoom(shots: [shot], key: nil), live]

        let added = await ScrapbookArchiveSync(modelContext: context, roomService: service).run()

        #expect(added == 0)
        #expect(service.downloads.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Scrapbook>()).isEmpty)
    }

    @Test func shotSealedWithAnotherKeyIsNotRestored() async throws {
        let shot = try addShot(author: "host-1", at: 100)
        service.rooms = [endedRoom(shots: [shot], key: RollShotCrypto.newRollKey())]

        let added = await ScrapbookArchiveSync(modelContext: context, roomService: service).run()

        #expect(added == 0)
        #expect(try context.fetch(FetchDescriptor<ScrapPhoto>()).isEmpty)
    }
}
