import Foundation
import SwiftData

@Model
final class Scrapbook {
    var id: UUID = UUID()
    var title: String = ""
    @Attribute(.externalStorage) var coverPhotoData: Data?
    var createdDate: Date = Date.now
    var memberIDs: [String] = []
    var memberNames: [String] = []
    var sourceSessionID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \ScrapPhoto.scrapbook)
    var photos: [ScrapPhoto]? = []

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
