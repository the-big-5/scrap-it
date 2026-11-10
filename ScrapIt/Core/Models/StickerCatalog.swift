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
/// Fun (change 022): cut from the Figma image "stiker all 1" (1253:22092) using the white shapes of
/// "kosongan 1" (1253:22093), which is the empty sheet.
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

    /// Units = pixels of the Figma image (1285 × 1714).
    static let fun = StickerSet(
        id: "fun",
        name: "Fun",
        sheetAssetName: "sticker-sheet-fun",
        sheetSize: CGSize(width: 1285, height: 1714),
        stickers: [
            fun("star-big", 112.9, 191.4, 203.3, 224.0),
            fun("star-small", 349.5, 210.2, 139.9, 135.5),
            fun("exclamation", 584.8, 94.1, 130.5, 338.2),
            fun("question", 742.3, 34.5, 181.3, 447.4),
            fun("flower-pink", 910.4, 59.0, 362.0, 397.8),
            fun("star-left", 28.2, 383.4, 126.7, 128.6),
            fun("star-tiny", 244.7, 389.0, 82.2, 86.6),
            fun("star-right", 340.1, 375.8, 169.4, 166.9),
            fun("flower-yellow", 1000.1, 456.1, 213.3, 213.3),
            fun("yinyang", 168.8, 559.1, 240.3, 240.9),
            fun("cat", 503.8, 564.1, 296.2, 299.9),
            fun("sparkle-1", 847.7, 558.4, 90.4, 134.9),
            fun("sparkle-2", 946.8, 684.5, 77.2, 114.2),
            fun("sparkle-3", 37.6, 776.1, 73.4, 119.8),
            fun("sparkle-4", 138.0, 833.2, 73.4, 122.4),
            fun("sparkle-5", 1088.0, 756.1, 96.6, 131.1),
            fun("sparkle-6", 69.0, 934.3, 86.0, 137.4),
            fun("burst-green", 228.4, 936.1, 288.0, 273.6),
            fun("bolt", 584.8, 896.0, 186.4, 257.3),
            fun("cherry", 789.3, 811.9, 364.5, 402.2),
            fun("burst-orange", 171.3, 1257.4, 189.5, 219.6),
            fun("card", 400.9, 1273.1, 235.9, 346.3),
            fun("heart-blue", 756.1, 1365.3, 170.0, 163.1),
            fun("heart-purple", 1011.4, 1296.3, 197.0, 187.0),
            fun("ladybug", 69.0, 1430.6, 185.7, 242.2),
            fun("heart-pink", 685.8, 1527.2, 160.6, 151.2),
            fun("heart-red", 921.7, 1465.1, 205.2, 216.5),
        ]
    )

    static let sets = [travel, fun]

    static func set(withID id: String) -> StickerSet? {
        sets.first { $0.id == id }
    }

    static func sticker(withID id: String) -> (set: StickerSet, sticker: StickerDefinition)? {
        for set in sets {
            if let sticker = set.stickers.first(where: { $0.id == id }) {
                return (set, sticker)
            }
        }
        return nil
    }

    private static func fun(_ key: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> StickerDefinition {
        StickerDefinition(id: "fun.\(key)", name: key, assetName: "sticker-fun-\(key)",
                          frame: CGRect(x: x, y: y, width: width, height: height))
    }

    private static func sticker(_ key: String, _ name: String,
                                _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> StickerDefinition {
        StickerDefinition(id: "travel.\(key)", name: name, assetName: "sticker-travel-\(key)",
                          frame: CGRect(x: x, y: y, width: width, height: height))
    }
}
