import Foundation
import SwiftData

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
