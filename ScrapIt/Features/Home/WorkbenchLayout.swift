import CoreGraphics
import UIKit

/// Supported Workbench geometry designs: portrait phone/iPad fallback and Figma iPad landscape.
enum WorkbenchVariant: Equatable {
    case portrait
    case iPadLandscape
}

/// One desk object placed by top-left rect in the `402×874` portrait design.
struct DeskItem: Equatable {
    let asset: String
    let frame: CGRect

    init(_ asset: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        self.asset = asset
        self.frame = CGRect(x: x, y: y, width: width, height: height)
    }
}

/// One desk object placed by center, unrotated size, and clockwise rotation in the `1210×834` design.
struct LandscapeDeskItem: Equatable {
    let asset: String
    let center: CGPoint
    let size: CGSize
    let rotationDegrees: Double

    init(_ asset: String, centerX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat, rotation: Double = 0) {
        self.asset = asset
        self.center = CGPoint(x: centerX, y: centerY)
        self.size = CGSize(width: width, height: height)
        self.rotationDegrees = rotation
    }
}

/// Places the Workbench on any screen using uniform width scaling and vertical centering:
/// - `.portrait` (Figma "Home" 853:1703, 402×874) for iPhone and iPad Portrait.
/// - `.iPadLandscape` (Figma "IPAD - Home" 1563:34278, 1210×834) for iPad Landscape.
struct WorkbenchLayout: Equatable {
    static let designSize = CGSize(width: 402, height: 874)
    static let iPadLandscapeDesignSize = CGSize(width: 1210, height: 834)

    let variant: WorkbenchVariant
    let designSize: CGSize
    let scale: CGFloat
    /// Top-left of the Figma frame on screen.
    let origin: CGPoint

    static func variant(
        for container: CGSize,
        idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom
    ) -> WorkbenchVariant {
        idiom == .pad && container.width > container.height ? .iPadLandscape : .portrait
    }

    init(
        container: CGSize,
        idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom
    ) {
        self.init(container: container, variant: Self.variant(for: container, idiom: idiom))
    }

    init(container: CGSize, variant: WorkbenchVariant) {
        self.variant = variant
        let reference = variant == .iPadLandscape ? Self.iPadLandscapeDesignSize : Self.designSize
        self.designSize = reference
        self.scale = container.width / reference.width
        self.origin = CGPoint(x: 0, y: (container.height - reference.height * scale) / 2)
    }

    func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
    }

    func rect(_ r: CGRect) -> CGRect {
        CGRect(origin: point(r.origin), size: size(r.size))
    }

    func size(_ s: CGSize) -> CGSize {
        CGSize(width: s.width * scale, height: s.height * scale)
    }

    func length(_ v: CGFloat) -> CGFloat {
        v * scale
    }

    // MARK: - Active Variant Accessors

    var activeToolboxSize: CGSize {
        variant == .iPadLandscape ? Self.iPadToolboxSize : Self.toolboxSize
    }

    var activeToolboxIdleCenter: CGPoint {
        variant == .iPadLandscape ? Self.iPadToolboxIdleCenter : Self.toolboxIdleCenter
    }

    var activeToolboxActiveCenter: CGPoint {
        variant == .iPadLandscape ? Self.iPadToolboxActiveCenter : Self.toolboxActiveCenter
    }

    var activeToolboxIdleRotation: Double {
        variant == .iPadLandscape ? Self.iPadToolboxIdleRotation : Self.toolboxIdleRotation
    }

    var activeToolboxActiveRotation: Double {
        variant == .iPadLandscape ? Self.iPadToolboxActiveRotation : Self.toolboxActiveRotation
    }

    var activeToolboxActiveScale: CGFloat {
        variant == .iPadLandscape ? Self.iPadToolboxActiveScale : Self.toolboxActiveScale
    }

    var activeCameraSize: CGSize {
        variant == .iPadLandscape ? Self.iPadCameraSize : Self.cameraSize
    }

    var activeCameraIdleCenter: CGPoint {
        variant == .iPadLandscape ? Self.iPadCameraIdleCenter : Self.cameraIdleCenter
    }

    var activeCameraActiveCenter: CGPoint {
        variant == .iPadLandscape ? Self.iPadCameraActiveCenter : Self.cameraActiveCenter
    }

    var activeCameraIdleRotation: Double {
        variant == .iPadLandscape ? Self.iPadCameraIdleRotation : Self.cameraIdleRotation
    }

    var activeCameraActiveRotation: Double {
        variant == .iPadLandscape ? Self.iPadCameraActiveRotation : Self.cameraActiveRotation
    }

    var activeActionButtonsCenter: CGPoint {
        variant == .iPadLandscape ? Self.iPadActionButtonsCenter : Self.actionButtonsCenter
    }

    var activeActionButtonSize: CGSize {
        variant == .iPadLandscape ? Self.iPadActionButtonSize : Self.actionButtonSize
    }

    private var cameraBodyScaleFactor: CGFloat {
        activeCameraSize.width / Self.cameraSize.width
    }

    var activeCameraBodyWidth: CGFloat {
        Self.cameraBodyWidth * cameraBodyScaleFactor
    }

    var activeCameraBodyHeight: CGFloat {
        Self.cameraBodyHeight * cameraBodyScaleFactor
    }

    var activeCameraBodyCenterOffset: CGPoint {
        CGPoint(
            x: Self.cameraBodyCenterOffset.x * cameraBodyScaleFactor,
            y: Self.cameraBodyCenterOffset.y * cameraBodyScaleFactor
        )
    }

    func zoomedCameraCenter(container: CGSize, angle: Double, scale: CGFloat) -> CGPoint {
        Self.zoomedCameraCenter(
            container: container,
            layoutScale: self.scale,
            angle: angle,
            scale: scale,
            bodyCenterOffset: activeCameraBodyCenterOffset
        )
    }

    func fullBleedCameraScale(container: CGSize, angle: Double) -> CGFloat {
        Self.fullBleedCameraScale(
            container: container,
            layoutScale: scale,
            angle: angle,
            cameraSize: activeCameraSize
        )
    }

    func floatingCameraScale(container: CGSize, angle: Double) -> CGFloat {
        Self.floatingCameraScale(
            container: container,
            layoutScale: scale,
            angle: angle,
            cameraSize: activeCameraSize,
            bodyHeight: activeCameraBodyHeight
        )
    }
}

// MARK: - Portrait (402×874, Figma 853:1703)

extension WorkbenchLayout {
    /// Desk objects in Figma layer order (back to front). Camera, toolbox, and tutorial book are separate interactive layers.
    static let deskItems: [DeskItem] = [
        DeskItem("DeskWood", 0, 0, 402, 874),
        DeskItem("DeskMatShadow", 0, 220, 402, 430),
        DeskItem("DeskShading", 0, 0, 402, 874),
        DeskItem("DeskCuttingMat", 0, 220, 402, 421),
        DeskItem("DeskMeasurements", 0, 220, 402, 421),
        DeskItem("DeskWoodGrain", 0, 0, 402, 874),
        DeskItem("DeskRuler", 173, 615, 229, 259),
        DeskItem("DeskBookBottom", 0, 509, 259.139, 365),
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

    /// Red open toolbox ("stat 1"): unclipped size, idle desk spot (Figma 920:3092), and centered active spot (Figma 1230:20860).
    static let toolboxSize = CGSize(width: 311.944, height: 416.129)
    static let toolboxIdleCenter = CGPoint(x: 264.558, y: 200.304)
    static let toolboxActiveCenter = CGPoint(x: 192.756, y: 450.046)
    static let toolboxIdleRotation: Double = -70.96
    static let toolboxActiveRotation: Double = -89.62
    static let toolboxActiveScale: CGFloat = 281.595 / 311.944

    /// Tutorial book (front-most desk object, tappable).
    static let tutorialBook = DeskItem("DeskBookTutorial", 0, 549, 223.107, 303.067)

    /// Disposable camera ("dispo 1" / "dispo 2"): unrotated size and centers in the 402×874 design.
    static let cameraSize = CGSize(width: 291.357, height: 218.411)
    static let cameraIdleCenter = CGPoint(x: 111.707, y: 375.738)
    static let cameraActiveCenter = CGPoint(x: 155.058, y: 335.149)
    static let cameraIdleRotation: Double = -14.77
    static let cameraActiveRotation: Double = 0.77

    /// Visual dimensions and center offset of the physical disposable camera body within its exported asset frame (in 402×874 design points).
    static let cameraBodyWidth: CGFloat = 213.5
    static let cameraBodyHeight: CGFloat = 111.5
    static let cameraBodyCenterOffset = CGPoint(x: -2.0, y: 10.5)

    /// Target center for the zoomed-in camera during the return transition (change 086).
    /// Centers the actual physical camera body on screen for portrait and landscape orientations.
    static func zoomedCameraCenter(
        container: CGSize,
        layoutScale: CGFloat,
        angle: Double,
        scale: CGFloat,
        bodyCenterOffset: CGPoint = WorkbenchLayout.cameraBodyCenterOffset
    ) -> CGPoint {
        let screenCenter = CGPoint(x: container.width / 2, y: container.height / 2)
        let rad = angle * .pi / 180.0
        let rx = (bodyCenterOffset.x * cos(rad) - bodyCenterOffset.y * sin(rad)) * scale * layoutScale
        let ry = (bodyCenterOffset.x * sin(rad) + bodyCenterOffset.y * cos(rad)) * scale * layoutScale
        return CGPoint(x: screenCenter.x - rx, y: screenCenter.y - ry)
    }

    /// Scale required for the camera element when zoomed in (change 086).
    /// For portrait, scales to cover the viewport; for landscape, scales to fit vertically with margin from the screen edges.
    static func zoomedCameraScale(container: CGSize, layoutScale: CGFloat, angle: Double) -> CGFloat {
        guard layoutScale > 0 else { return 1.0 }
        let isLandscapeAngle = abs(abs(angle) - 90.0) < 1.0
        if isLandscapeAngle {
            let shortEdge = min(container.width, container.height)
            let targetVerticalHeight = max(shortEdge - 80 * layoutScale, 260)
            return targetVerticalHeight / (cameraBodyHeight * layoutScale)
        } else {
            let scaleX = container.width / (cameraSize.width * layoutScale)
            let scaleY = container.height / (cameraSize.height * layoutScale)
            return max(scaleX, scaleY) * 1.05
        }
    }

    /// Scale for full-bleed camera element covering screen edge-to-edge (change 100).
    static func fullBleedCameraScale(
        container: CGSize,
        layoutScale: CGFloat,
        angle: Double,
        cameraSize: CGSize = WorkbenchLayout.cameraSize
    ) -> CGFloat {
        guard layoutScale > 0 else { return 1.0 }
        let isLandscapeAngle = abs(abs(angle) - 90.0) < 1.0
        if isLandscapeAngle {
            let scaleX = container.height / (cameraSize.width * layoutScale)
            let scaleY = container.width / (cameraSize.height * layoutScale)
            return max(scaleX, scaleY) * 1.08
        } else {
            let scaleX = container.width / (cameraSize.width * layoutScale)
            let scaleY = container.height / (cameraSize.height * layoutScale)
            return max(scaleX, scaleY) * 1.08
        }
    }

    /// Scale for floating camera element with margins prior to 3D flip (change 100).
    static func floatingCameraScale(
        container: CGSize,
        layoutScale: CGFloat,
        angle: Double,
        cameraSize: CGSize = WorkbenchLayout.cameraSize,
        bodyHeight: CGFloat = WorkbenchLayout.cameraBodyHeight
    ) -> CGFloat {
        guard layoutScale > 0 else { return 1.0 }
        let isLandscapeAngle = abs(abs(angle) - 90.0) < 1.0
        if isLandscapeAngle {
            let maxBodyHeightByWidth = max(container.width - 80 * layoutScale, 200)
            let maxCardLengthByHeight = max(container.height * 0.82, 260)
            let scaleByWidth = maxBodyHeightByWidth / (bodyHeight * layoutScale)
            let scaleByHeight = maxCardLengthByHeight / (cameraSize.width * layoutScale)
            return min(scaleByWidth, scaleByHeight)
        } else {
            let targetWidth = max(min(container.width - 64 * layoutScale, container.height * 0.72), 240)
            return targetWidth / (cameraSize.width * layoutScale)
        }
    }

    /// Create Roll / Join a Roll stack center in the 402×874 design.
    static let actionButtonsCenter = CGPoint(x: 155, y: 495)
    static let actionButtonSize = CGSize(width: 217, height: 52)
}

// MARK: - iPad Landscape (1210×834, Figma 1563:34278)

extension WorkbenchLayout {
    static let iPadCuttingMatRect = CGRect(x: 0, y: 91, width: 1210, height: 652)

    /// Film canisters sitting on the mat in 1563:34278 (reusing existing unclipped assets).
    static let iPadCanisters: [LandscapeDeskItem] = [
        LandscapeDeskItem("DeskFilmRoll4", centerX: 895.5, centerY: 541, width: 252, height: 229, rotation: 0),
        LandscapeDeskItem("DeskFilmRoll2", centerX: 727, centerY: 600, width: 314, height: 302, rotation: 12),
        LandscapeDeskItem("DeskFilmRoll3", centerX: 858, centerY: 705, width: 303, height: 314.5, rotation: 0),
    ]

    /// Blue memories book (Figma 1563:34908 `buku bawah 1`), unclipped asset.
    static let iPadBookBottom = LandscapeDeskItem(
        "DeskBookBottomLandscape",
        centerX: 202.667,
        centerY: 595.173,
        width: 330.717,
        height: 441.171,
        rotation: -24.38
    )

    /// Tutorial spiral notebook (Figma 1563:34915 `buku atas 3 1`), reusing `DeskBookTutorial`.
    static let iPadTutorialBook = LandscapeDeskItem(
        "DeskBookTutorial",
        centerX: 291.892,
        centerY: 590.473,
        width: 337.688,
        height: 450.470,
        rotation: -9.26
    )

    /// Red open toolbox (`stat 1`, Figma 1563:34910), rendered via `InteractiveToolboxView`.
    static let iPadToolboxSize = CGSize(width: 510.146, height: 680.527)
    static let iPadToolboxIdleCenter = CGPoint(x: 888.849, y: 253.102)
    static let iPadToolboxActiveCenter = CGPoint(x: 605, y: 417)
    static let iPadToolboxIdleRotation: Double = -70.96
    static let iPadToolboxActiveRotation: Double = -89.62
    static let iPadToolboxActiveScale: CGFloat = 380.0 / 510.146

    /// Disposable camera (Figma 1563:34914 `dispo 1`), reusing `DeskDisposableCamera`.
    static let iPadCameraSize = CGSize(width: 471.433, height: 353.402)
    static let iPadCameraIdleCenter = CGPoint(x: 400.375, y: 258.428)
    static let iPadCameraActiveCenter = CGPoint(x: 605, y: 270)
    static let iPadCameraIdleRotation: Double = -2.91
    static let iPadCameraActiveRotation: Double = 0.77

    /// Create Roll / Join a Roll stack centered beneath the active camera in 1210×834.
    static let iPadActionButtonsCenter = CGPoint(x: 605, y: 550)
    static let iPadActionButtonSize = CGSize(width: 260, height: 58)
}
