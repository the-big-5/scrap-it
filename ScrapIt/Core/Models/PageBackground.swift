import Foundation

/// Page background (change 013, POC list; may change with the design). Stored in `ScrapbookPage.background`.
enum PageBackground: String, CaseIterable, Identifiable {
    case cream = "color.cream"
    case white = "color.white"
    case kraft = "color.kraft"
    case black = "color.black"
    case pink = "color.pink"
    case sky = "color.sky"
    case mint = "color.mint"
    case lined = "paper.lined"
    case grid = "paper.grid"
    case dotted = "paper.dotted"

    enum Pattern {
        case none, lined, grid, dotted
    }

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cream: "Cream"
        case .white: "White"
        case .kraft: "Kraft"
        case .black: "Black"
        case .pink: "Pink"
        case .sky: "Sky"
        case .mint: "Mint"
        case .lined: "Lined"
        case .grid: "Grid"
        case .dotted: "Dotted"
        }
    }

    /// RGB 0–1.
    var baseRGB: (red: Double, green: Double, blue: Double) {
        switch self {
        case .cream: (0.97, 0.94, 0.87)
        case .white: (1, 1, 1)
        case .kraft: (0.78, 0.64, 0.47)
        case .black: (0.1, 0.1, 0.1)
        case .pink: (0.98, 0.86, 0.88)
        case .sky: (0.85, 0.92, 0.98)
        case .mint: (0.86, 0.95, 0.9)
        case .lined, .grid, .dotted: (0.98, 0.97, 0.93)
        }
    }

    var pattern: Pattern {
        switch self {
        case .lined: .lined
        case .grid: .grid
        case .dotted: .dotted
        default: .none
        }
    }
}
