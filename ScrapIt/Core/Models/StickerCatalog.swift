import CoreGraphics

/// One sticker on a sheet. `frame` is in the sheet's SVG units (e.g. 318 × 355).
struct StickerDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let assetName: String
    let frame: CGRect

    var aspectRatio: CGFloat { frame.width / frame.height }
}

/// A sticker set: the empty sheet image (glue marks) plus the stickers in their places.
struct StickerSet: Identifiable {
    let id: String
    let name: String
    let sheetAssetName: String
    let sheetSize: CGSize
    let stickers: [StickerDefinition]
}

/// Stickers from the camera POC (change 013). Temporary: the set may change with the design.
enum StickerCatalog {
    static let travel = StickerSet(
        id: "travel",
        name: "Travel",
        sheetAssetName: "sticker-sheet-travel",
        sheetSize: CGSize(width: 318, height: 355),
        stickers: [
            sticker("airplane", "Airplane", 11.5, 29.5, 95, 55),
            sticker("scooter", "My Adventure", 124.5, 17.5, 90, 69.25),
            sticker("train", "Exploring", 224.5, 15.75, 84.25, 69),
            sticker("passport", "Passport", 24.5, 112.5, 73, 93),
            sticker("bag", "Shopping Bag", 120.5, 112.5, 80, 102.5),
            sticker("food", "Food Traveller", 223.5, 121.5, 82, 86),
            sticker("cityguide", "City Guide", 124.5, 236.5, 84.75, 86),
            sticker("camera", "Capture the Moment", 17.5, 235.5, 92, 77.75),
            sticker("money", "Travel More", 224.5, 229.5, 77.75, 87.75),
        ]
    )

    static let sets = [travel]

    static func sticker(withID id: String) -> (set: StickerSet, sticker: StickerDefinition)? {
        for set in sets {
            if let sticker = set.stickers.first(where: { $0.id == id }) {
                return (set, sticker)
            }
        }
        return nil
    }

    private static func sticker(_ key: String, _ name: String,
                                _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> StickerDefinition {
        StickerDefinition(id: "travel.\(key)", name: name, assetName: "sticker-travel-\(key)",
                          frame: CGRect(x: x, y: y, width: width, height: height))
    }
}
