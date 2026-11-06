import CoreGraphics

/// Places the Workbench (Figma "Home" 853:1703, 402×874) on any screen:
/// one uniform scale so the Figma frame width = screen width, the desk centered vertically.
/// Objects keep their Figma position, size and rotation (no separate X/Y stretching).
struct WorkbenchLayout: Equatable {
    static let designSize = CGSize(width: 402, height: 874)

    let scale: CGFloat
    /// Top-left of the Figma frame on screen.
    let origin: CGPoint

    init(container: CGSize) {
        scale = container.width / Self.designSize.width
        origin = CGPoint(x: 0, y: (container.height - Self.designSize.height * scale) / 2)
    }

    func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
    }

    func rect(_ r: CGRect) -> CGRect {
        CGRect(origin: point(r.origin), size: CGSize(width: r.width * scale, height: r.height * scale))
    }

    func length(_ v: CGFloat) -> CGFloat {
        v * scale
    }
}

/// One desk object: an asset exported from Figma and its frame in the 402×874 design.
/// Frames are the export bounds (layer + its drop shadow, clipped to the Figma frame).
struct DeskItem: Equatable {
    let asset: String
    let frame: CGRect

    init(_ asset: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        self.asset = asset
        self.frame = CGRect(x: x, y: y, width: width, height: height)
    }
}

extension WorkbenchLayout {
    /// Desk objects in Figma layer order (back to front). The camera is separate (it animates).
    static let deskItems: [DeskItem] = [
        DeskItem("DeskWood", 0, 0, 402, 874),
        DeskItem("DeskMatShadow", 0, 220, 402, 430),
        DeskItem("DeskShading", 0, 0, 402, 874),
        DeskItem("DeskCuttingMat", 0, 220, 402, 421),
        DeskItem("DeskMeasurements", 0, 220, 402, 421),
        DeskItem("DeskWoodGrain", 0, 0, 402, 874),
        DeskItem("DeskRuler", 173, 615, 229, 259),
        DeskItem("DeskBookBottom", 0, 509, 259.139, 365),
        DeskItem("DeskToolbox", 13, 0, 389, 423.607),
        DeskItem("DeskFilmRoll4", 272, 454, 130, 118),
        DeskItem("DeskFilmRoll3", 243, 516, 159, 165.032),
        DeskItem("DeskFilmRoll2", 170, 457, 167.989, 161.748),
        DeskItem("DeskPaperBall1", 0, 174, 44, 67),
        DeskItem("DeskPaperBall2", 338, 806, 64, 68),
        DeskItem("DeskStationery1", 281, 364, 92, 80),
        DeskItem("DeskStationery4", 0, 83, 85.133, 82.007),
        DeskItem("DeskStationery2", 40, 45, 92, 80),
        DeskItem("DeskStationery3", 187, 729, 92, 80),
        DeskItem("DeskStationery5", 326, 396, 76, 90.522),
    ]

    /// Tutorial book (front-most desk object, tappable).
    static let tutorialBook = DeskItem("DeskBookTutorial", 0, 549, 223.107, 303.067)

    /// Disposable camera ("dispo 1" / "dispo 2"): unrotated size and centers in the design.
    static let cameraSize = CGSize(width: 291.357, height: 218.411)
    static let cameraIdleCenter = CGPoint(x: 111.707, y: 375.738)
    static let cameraActiveCenter = CGPoint(x: 155.058, y: 335.149)
    static let cameraIdleRotation: Double = -14.77
    static let cameraActiveRotation: Double = 0.77

    /// Create Roll / Join a Roll stack center (unchanged from the previous Workbench).
    static let actionButtonsCenter = CGPoint(x: 155, y: 495)
    static let actionButtonSize = CGSize(width: 217, height: 52)
}
