import SwiftUI

/// Tray look from Figma (change 022, camera POC): red leather with dashed stitching.
enum TrayStyle {
    static let leather = Color(red: 0.51, green: 0.08, blue: 0.08)
    static let leatherDark = Color(red: 0.41, green: 0.07, blue: 0.07)
    static let trayHeight: CGFloat = 106
    /// The second tray overlaps the main tray by this much.
    static let overlap: CGFloat = 18
    static let closedSize: CGFloat = 96
    /// Stitching inset from the tray edge; tray content stays inside the stitching.
    static let stitchInset: CGFloat = 8
    /// Bottom of the second tray's content (its lower part is behind the main tray).
    static let subTrayContentBottom: CGFloat = trayHeight - overlap
    /// Height kept free under the page for the open trays.
    static let reservedHeight: CGFloat = 220
}

/// How each main tray tool is drawn: the image and the part showing above the tray's pocket (Figma).
extension ScrapbookTool {
    var assetName: String { "tray-tool-\(rawValue)" }

    /// Full image height (pt). The pencil uses its long original image (Figma 48 × 272, slightly smaller);
    /// the others equal their visible part.
    var imageHeight: CGFloat {
        switch self {
        case .pencil: 240
        // The scissors are shown whole (not in the pocket).
        case .scissors: 76
        default: visibleHeight
        }
    }

    /// Part showing above the tray's pocket (pt), from Figma.
    var visibleHeight: CGFloat {
        switch self {
        case .scissors: 76
        case .pencil: 70
        case .sticker: 72
        case .photo: 66
        case .washi: 58
        case .letters: 68
        case .text: 66
        }
    }

    /// Horizontal shift so the tool's body is centered (the pen's clip makes its image lopsided; brief F9).
    var centerOffset: CGFloat {
        self == .pencil ? -5 : 0
    }
}

/// Red leather with dashed stitching, as in Figma.
struct TrayBackground<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        shape
            .fill(LinearGradient(colors: [TrayStyle.leather, TrayStyle.leatherDark], startPoint: .top, endPoint: .bottom))
            .overlay {
                shape.inset(by: 1).stroke(Color.black.opacity(0.35), lineWidth: 2)
            }
            .overlay {
                shape.inset(by: 6)
                    .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            }
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
    }
}
