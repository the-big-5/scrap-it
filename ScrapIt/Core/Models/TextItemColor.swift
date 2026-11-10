import Foundation

/// Plain text colors (change 022, camera POC). `rawValue` is stored in `ScrapbookItem.textColor`.
enum TextItemColor: String, CaseIterable, Identifiable {
    case black, white, red, blue, green, yellow, pink

    var id: String { rawValue }

    static func from(_ key: String?) -> TextItemColor {
        key.flatMap(TextItemColor.init(rawValue:)) ?? .black
    }
}

/// Plain text size: font size = `ScrapbookItem.width` × page width.
enum TextItemStyle {
    static let defaultSize: Double = 0.08
    /// Text wraps at this share of the page width.
    static let maxWidthRatio: Double = 0.8
}
