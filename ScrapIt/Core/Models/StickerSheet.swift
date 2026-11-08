import Foundation
import SwiftData

/// A scrapbook's supply of one sticker set (change 013, POC). A used sticker can't be taken again
/// until the user takes a new sheet.
@Model
final class StickerSheet {
    var id: UUID = UUID()
    var setID: String = ""
    var usedStickerIDs: [String] = []
    var createdAt: Date = Date.now
    var scrapbook: Scrapbook?

    init(setID: String) {
        self.setID = setID
    }

    func isUsed(_ sticker: StickerDefinition) -> Bool {
        usedStickerIDs.contains(sticker.id)
    }

    func remainingCount(in set: StickerSet) -> Int {
        set.stickers.filter { !isUsed($0) }.count
    }
}
