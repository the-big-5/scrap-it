import CoreGraphics

/// One cut-out letter (magazine clipping). Size from the Figma SVG, in points.
struct LetterDefinition: Identifiable, Hashable {
    let id: String
    let character: String
    let size: CGSize

    var assetName: String { "letter-\(character)" }
    var aspectRatio: CGFloat { size.width / size.height }
}

/// Letters A–Z and digits 0–9 from Figma (node 1180:6896), change 022 ported from the camera POC.
/// Reusable: every letter can be placed any number of times.
enum LetterCatalog {
    /// Letter height when placed, relative to the page width.
    static let placedHeight: CGFloat = 0.12

    static let letters: [LetterDefinition] = [
        ("A", 62, 70), ("B", 43, 66), ("C", 74, 78), ("D", 54, 63), ("E", 55, 76), ("F", 50, 87),
        ("G", 50, 55), ("H", 62, 79), ("I", 36, 84), ("J", 50, 76), ("K", 57, 65), ("L", 76, 82),
        ("M", 71, 67), ("N", 38, 76), ("O", 40, 70), ("P", 82, 74), ("Q", 63, 71), ("R", 60, 79),
        ("S", 42, 70), ("T", 76, 78), ("U", 68, 68), ("V", 66, 68), ("W", 52, 61), ("X", 45, 66),
        ("Y", 77, 77), ("Z", 45, 69),
        ("0", 76, 83), ("1", 52, 77), ("2", 53, 71), ("3", 53, 59), ("4", 49, 60), ("5", 63, 74),
        ("6", 55, 67), ("7", 60, 66), ("8", 38, 74), ("9", 50, 69),
    ].map { LetterDefinition(id: "letter.\($0.0)", character: $0.0, size: CGSize(width: $0.1, height: $0.2)) }

    static func letter(withID id: String) -> LetterDefinition? {
        letters.first { $0.id == id }
    }
}
