import CoreGraphics
import Foundation
import SwiftData

/// A photo or sticker on a page (change 013). Position and width are normalized (0–1) to the page;
/// the height follows the photo's / sticker's aspect ratio.
@Model
final class ScrapbookItem {
    static let minWidth = 0.15
    static let maxWidth = 1.0

    var id: UUID = UUID()
    /// `ScrapPhoto.id`; `nil` for stickers.
    var photoID: UUID?
    /// `StickerCatalog` id; set for stickers.
    var stickerID: String?
    var centerX: Double = 0.5
    var centerY: Double = 0.5
    var width: Double = 0.45
    /// Radians.
    var rotation: Double = 0
    var zIndex: Int = 0
    /// Live Photo motion on / off for this item.
    var loopEnabled: Bool = true
    /// Scissors cut shape: JSON `[[x, y], …]` normalized to the item's box (photo + white frame). `nil` = whole photo.
    var maskData: Data?
    var page: ScrapbookPage?

    init(
        photoID: UUID? = nil,
        stickerID: String? = nil,
        centerX: Double,
        centerY: Double,
        width: Double,
        rotation: Double,
        zIndex: Int,
        loopEnabled: Bool = true
    ) {
        self.photoID = photoID
        self.stickerID = stickerID
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.rotation = rotation
        self.zIndex = zIndex
        self.loopEnabled = loopEnabled
    }

    var sticker: StickerDefinition? {
        stickerID.flatMap { StickerCatalog.sticker(withID: $0)?.sticker }
    }

    /// Cut polygon; `nil` = whole photo. Broken data counts as a whole photo.
    var maskPolygon: [CGPoint]? {
        get {
            guard let maskData, let pairs = try? JSONDecoder().decode([[Double]].self, from: maskData),
                  pairs.count >= 3, pairs.allSatisfy({ $0.count == 2 }) else { return nil }
            return pairs.map { CGPoint(x: $0[0], y: $0[1]) }
        }
        set {
            maskData = newValue.flatMap { try? JSONEncoder().encode($0.map { [Double($0.x), Double($0.y)] }) }
        }
    }
}
