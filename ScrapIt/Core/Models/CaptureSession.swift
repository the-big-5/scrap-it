import Foundation
import SwiftData

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
