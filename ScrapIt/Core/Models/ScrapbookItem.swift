import CoreGraphics
import Foundation
import SwiftData

/// An item on a page (change 013): photo, sticker, cut-out letter, text, washi tape or drawing layer (change 022).
/// The kind comes from the filled field (`kind`). Position and width are normalized (0–1) to the page;
/// the height follows the content's aspect ratio.
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
    /// `LetterCatalog` id, e.g. `letter.A` (change 022).
    var letterID: String?
    /// Plain text. For text, `width` is the font size relative to the page width (change 022).
    var text: String?
    /// `TextItemColor` key.
    var textColor: String?
    /// `WashiCatalog` id (change 022).
    var washiID: String?
    /// Tape length when torn, relative to the page width. With the tape width it sets the item's ratio.
    var washiLength: Double?
    /// Seed of the jagged ends of the tape.
    var tearSeed: Int?
    /// Drawing layer (change 022): `PKDrawing.dataRepresentation()` in `ScrapbookPage.canvasSize` points;
    /// empty data = a layer without strokes yet. The layer always covers the whole page.
    @Attribute(.externalStorage) var drawingData: Data?
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

    var kind: ScrapbookItemKind {
        if drawingData != nil { return .drawing }
        if stickerID != nil { return .sticker }
        if letterID != nil { return .letter }
        if text != nil { return .text }
        if washiID != nil { return .washi }
        return .photo
    }

    /// `width` limits per kind: letters and washi go much smaller / longer than photos.
    var widthRange: ClosedRange<Double> {
        switch kind {
        case .photo, .sticker: Self.minWidth...Self.maxWidth
        case .letter: 0.04...0.8
        // On the narrow spine the font size can grow up to the spine's width (change 026).
        case .text: page?.role == ScrapbookPage.Role.spine.rawValue ? 0.1...1.0 : 0.03...0.3
        case .washi: 0.05...1.6
        case .drawing: 1...1
        }
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

enum ScrapbookItemKind {
    case photo, sticker, letter, text, washi, drawing
}

extension ScrapbookItem {
    func toPayload() -> ScrapbookItemPayload {
        ScrapbookItemPayload(
            id: id,
            photoID: photoID,
            stickerID: stickerID,
            centerX: centerX,
            centerY: centerY,
            width: width,
            rotation: rotation,
            zIndex: zIndex,
            loopEnabled: loopEnabled,
            maskData: maskData,
            letterID: letterID,
            text: text,
            textColor: textColor,
            washiID: washiID,
            washiLength: washiLength,
            tearSeed: tearSeed,
            drawingData: drawingData
        )
    }

    convenience init(payload: ScrapbookItemPayload) {
        self.init(
            photoID: payload.photoID,
            stickerID: payload.stickerID,
            centerX: payload.centerX,
            centerY: payload.centerY,
            width: payload.width,
            rotation: payload.rotation,
            zIndex: payload.zIndex,
            loopEnabled: payload.loopEnabled
        )
        self.id = payload.id
        self.maskData = payload.maskData
        self.letterID = payload.letterID
        self.text = payload.text
        self.textColor = payload.textColor
        self.washiID = payload.washiID
        self.washiLength = payload.washiLength
        self.tearSeed = payload.tearSeed
        self.drawingData = payload.drawingData
    }
}
