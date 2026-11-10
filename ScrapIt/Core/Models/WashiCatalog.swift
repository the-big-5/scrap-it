import Foundation

/// Washi tape patterns from the Figma Washi tray (change 022, camera POC). The pattern is drawn in code
/// (`WashiTapeView`), so it repeats along the tape without stretching.
enum WashiMotif {
    case triangles, crosses, waves, flowers
}

struct WashiStyle: Identifiable, Hashable {
    let id: String
    let rollAssetName: String
    let motif: WashiMotif
}

enum WashiCatalog {
    /// Tape width relative to the page width (64 pt of 402 pt in Figma).
    static let tapeWidth: Double = 0.16
    /// Shorter pulls are cancelled.
    static let minimumLength: Double = 0.1
    static let opacity: Double = 0.88

    static let styles: [WashiStyle] = [
        WashiStyle(id: "washi.triangles", rollAssetName: "tray-washi-1", motif: .triangles),
        WashiStyle(id: "washi.crosses", rollAssetName: "tray-washi-2", motif: .crosses),
        WashiStyle(id: "washi.waves", rollAssetName: "tray-washi-3", motif: .waves),
        WashiStyle(id: "washi.flowers", rollAssetName: "tray-washi-4", motif: .flowers),
    ]

    static func style(withID id: String) -> WashiStyle? {
        styles.first { $0.id == id }
    }
}
