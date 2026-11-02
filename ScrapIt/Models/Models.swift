import Foundation
import SwiftData

enum RollFilter: String, Codable, CaseIterable, Identifiable {
    case cinematicBW400 = "cinematic_bw_400"
    case colorPrint200 = "color_print_200"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cinematicBW400:
            return "Cinematic 400 Pro 35 Black & White"
        case .colorPrint200:
            return "200 Color Print"
        }
    }

    var shortLabel: String {
        switch self {
        case .cinematicBW400:
            return "PRO 35 B&W 400"
        case .colorPrint200:
            return "COLOR PRINT 200"
        }
    }
}

enum SessionStatus: String, Codable {
    case waiting
    case live
    case ended
}

@Model
final class UserProfile {
    @Attribute(.unique) var appleUserID: String
    var name: String
    @Attribute(.externalStorage) var avatarData: Data?
    var createdAt: Date

    init(appleUserID: String, name: String, avatarData: Data? = nil, createdAt: Date = .now) {
        self.appleUserID = appleUserID
        self.name = name
        self.avatarData = avatarData
        self.createdAt = createdAt
    }
}

@Model
final class Scrapbook {
    @Attribute(.unique) var id: UUID
    var title: String
    @Attribute(.externalStorage) var coverPhotoData: Data?
    var createdDate: Date
    var memberIDs: [String]
    var memberNames: [String]
    var sourceSessionID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \ScrapPhoto.scrapbook)
    var photos: [ScrapPhoto] = []

    init(
        id: UUID = UUID(),
        title: String,
        coverPhotoData: Data? = nil,
        createdDate: Date = .now,
        memberIDs: [String] = [],
        memberNames: [String] = [],
        sourceSessionID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.coverPhotoData = coverPhotoData
        self.createdDate = createdDate
        self.memberIDs = memberIDs
        self.memberNames = memberNames
        self.sourceSessionID = sourceSessionID
    }
}

@Model
final class ScrapPhoto {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    @Attribute(.externalStorage) var livePhotoMovieData: Data?
    var caption: String
    var authorID: String
    var authorName: String
    var timestamp: Date
    var sourceSessionID: UUID
    var isSyncedToCloud: Bool
    var scrapbook: Scrapbook?

    init(
        id: UUID = UUID(),
        imageData: Data,
        livePhotoMovieData: Data? = nil,
        caption: String = "",
        authorID: String,
        authorName: String,
        timestamp: Date = .now,
        sourceSessionID: UUID,
        isSyncedToCloud: Bool = false,
        scrapbook: Scrapbook? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.livePhotoMovieData = livePhotoMovieData
        self.caption = caption
        self.authorID = authorID
        self.authorName = authorName
        self.timestamp = timestamp
        self.sourceSessionID = sourceSessionID
        self.isSyncedToCloud = isSyncedToCloud
        self.scrapbook = scrapbook
    }
}

@Model
final class CaptureSession {
    @Attribute(.unique) var id: UUID
    var name: String
    var rollCode: String
    var shareURLString: String?
    var ckRecordName: String?
    var hostUserID: String
    var participantIDs: [String]
    var participantNames: [String]
    var rollSize: Int
    var slotsUsed: Int
    var filterRaw: String
    var statusRaw: String
    var startTime: Date
    var endTime: Date?
    var createdScrapbookID: UUID?

    var filter: RollFilter {
        get { RollFilter(rawValue: filterRaw) ?? .colorPrint200 }
        set { filterRaw = newValue.rawValue }
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .waiting }
        set { statusRaw = newValue.rawValue }
    }

    var remainingSlots: Int {
        max(0, rollSize - slotsUsed)
    }

    init(
        id: UUID = UUID(),
        name: String,
        rollCode: String = CaptureSession.generateRollCode(),
        shareURLString: String? = nil,
        ckRecordName: String? = nil,
        hostUserID: String,
        participantIDs: [String],
        participantNames: [String],
        rollSize: Int = 36,
        slotsUsed: Int = 0,
        filter: RollFilter = .colorPrint200,
        status: SessionStatus = .waiting,
        startTime: Date = .now,
        endTime: Date? = nil,
        createdScrapbookID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.rollCode = rollCode
        self.shareURLString = shareURLString
        self.ckRecordName = ckRecordName
        self.hostUserID = hostUserID
        self.participantIDs = participantIDs
        self.participantNames = participantNames
        self.rollSize = rollSize
        self.slotsUsed = slotsUsed
        self.filterRaw = filter.rawValue
        self.statusRaw = status.rawValue
        self.startTime = startTime
        self.endTime = endTime
        self.createdScrapbookID = createdScrapbookID
    }

    static func generateRollCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }

    var inviteURL: URL {
        if let shareURLString, let url = URL(string: shareURLString) {
            return url
        }
        return URL(string: "scrapit://join?code=\(rollCode)")!
    }
}
