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
    /// Editor pages and sticker supply (change 013, local only).
    @Relationship(deleteRule: .cascade, inverse: \ScrapbookPage.scrapbook)
    var pages: [ScrapbookPage]? = []
    @Relationship(deleteRule: .cascade, inverse: \StickerSheet.scrapbook)
    var stickerSheets: [StickerSheet]? = []
    /// Tools whose hint was already shown in this scrapbook (`ScrapbookTool.rawValue`, change 022).
    var shownToolHints: [String] = []
    /// Cover color as "#RRGGBB" (change 026); the cover starts white.
    var coverColorHex: String = "#FFFFFF"
    /// Saved by the host: nobody can change it any more (change 026).
    var isLocked: Bool = false
    var lockedAt: Date?
    /// This phone's user tapped Done in the book view: the pages can't be edited again (change 026).
    var hasFinishedPages: Bool = false
    /// Members whose editing is done (participants after Done Editing, the host after Done), from the room (change 026).
    var doneEditingMemberIDs: [String] = []

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

    /// The book's pages, without the cover (change 026).
    var sortedPages: [ScrapbookPage] {
        (pages ?? []).filter { $0.role == nil }.sorted { $0.order < $1.order }
    }

    /// The front cover or the spine (change 026), if created.
    func coverPage(_ role: ScrapbookPage.Role) -> ScrapbookPage? {
        (pages ?? []).first { $0.role == role.rawValue }
    }
}
