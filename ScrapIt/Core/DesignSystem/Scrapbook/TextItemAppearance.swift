import SwiftUI

/// Colors and font of plain text items (change 022, camera POC).
extension TextItemColor {
    var color: Color {
        switch self {
        case .black: Color(red: 0.11, green: 0.09, blue: 0.15)
        case .white: .white
        // Tray leather red.
        case .red: Color(red: 0.51, green: 0.08, blue: 0.08)
        case .blue: Color(red: 0, green: 0.45, blue: 0.73)
        case .green: Color(red: 0.12, green: 0.65, blue: 0.6)
        case .yellow: Color(red: 0.99, green: 0.79, blue: 0.34)
        case .pink: Color(red: 0.92, green: 0.11, blue: 0.41)
        }
    }
}

extension TextItemStyle {
    /// One font for now: system serif, semibold.
    static func font(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
}
