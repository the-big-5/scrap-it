import SwiftUI

/// Scissors layer over the page (change 013, same behavior as the POC):
/// - One finger drag anywhere: cuts. The scissors appear at the finger and the cut line starts where it touched.
/// - Long press (±0.4 s) on a photo, then drag: moves the photo / piece.
/// - Two fingers: pinch and rotate the item under the fingers.
/// Only gesture state lives here; finding items, moving and cutting go through the ViewModel.
struct ScissorsToolView: View {
    typealias Frame = (centerX: Double, centerY: Double, width: Double, rotation: Double)

    /// Display size of the scissors asset (PNG 226 × 330 @3x).
    static let imageSize = CGSize(width: 75.3, height: 110)
    /// Blade tip in the image.
    static let tipAnchor = UnitPoint(x: 0.9985, y: 0)
    /// Blade direction in the image, from the middle to the tip (y down).
    static let bladeAngle = Angle.degrees(-59.2)
    static let holdDuration: Duration = .milliseconds(400)
    /// Moving this far before the long press finishes means cutting.
    static let moveTolerance: CGFloat = 6

    /// Topmost item at a page point: photo, piece or sticker.
    let itemAt: (CGPoint, CGSize) -> UUID?
    /// Whether the point is over a photo that can be cut (for the "snip" haptic).
    let isOverPhoto: (CGPoint, CGSize) -> Bool
    let itemFrame: (UUID) -> Frame?
    let onSelect: (UUID) -> Void
    let onMove: (UUID, Frame) -> Void
    let onFinishMove: (UUID) -> Void
    /// Returns `true` when a photo was cut.
    let onCut: ([CGPoint], CGSize) -> Bool
    var onDragMoved: (UUID, CGPoint) -> Void = { _, _ in }
    var onDropInTrash: (UUID) -> Bool = { _ in false }
    var onCancelDrag: () -> Void = {}

    private enum Mode {
        case pending, cutting, moving, transforming
    }

    @State private var mode: Mode?
    @State private var holdTask: Task<Void, Never>?
    @State private var touchStart: CGPoint = .zero
    @State private var manipulated: UUID?
    @State private var base: Frame?
    /// After two fingers, one-finger drags are ignored until all fingers lift.
    @State private var ignoresDragUntilRelease = false

    @State private var path: [CGPoint] = []
    @State private var lineOpacity: Double = 1
    @State private var heading = Self.bladeAngle
    @State private var snipScale: CGFloat = 1
    @State private var distanceSinceSnip: CGFloat = 0
    @State private var snipCount = 0
    @State private var cutCount = 0
    @State private var liftCount = 0

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                Color.clear

                Canvas { context, _ in
                    guard path.count > 1 else { return }
                    var line = Path()
                    line.addLines(path)
                    context.stroke(line, with: .color(.black.opacity(0.45)),
                                   style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round, dash: [7, 5]))
                    context.stroke(line, with: .color(.white),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [7, 5]))
                }
                .opacity(lineOpacity)

                if mode == .cutting, let tip = path.last {
                    scissors(at: tip)
                        .transition(.scale(scale: 0.8, anchor: Self.tipAnchor).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in dragChanged(value, size: size) }
                    .onEnded { _ in dragEnded(size: size) }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .simultaneously(with: RotateGesture())
                    .onChanged { value in transformChanged(value, size: size) }
                    .onEnded { _ in transformEnded() }
            )
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: snipCount)
        .sensoryFeedback(.impact(weight: .medium), trigger: cutCount)
        .sensoryFeedback(.impact(weight: .light), trigger: liftCount)
        .onDisappear {
            holdTask?.cancel()
            onCancelDrag()
        }
    }

    private func scissors(at tip: CGPoint) -> some View {
        let width = Self.imageSize.width, height = Self.imageSize.height
        return Image("scissors")
            .resizable()
            .frame(width: width, height: height)
            .scaleEffect(snipScale, anchor: Self.tipAnchor)
            .rotationEffect(heading - Self.bladeAngle, anchor: Self.tipAnchor)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
            // Blade tip right at the finger; rotation pivots on the tip so the line comes out of it.
            .position(x: tip.x + (0.5 - Self.tipAnchor.x) * width,
                      y: tip.y + (0.5 - Self.tipAnchor.y) * height)
            .allowsHitTesting(false)
            .accessibilityLabel("Scissors")
    }

    // MARK: - One finger

    private func dragChanged(_ value: DragGesture.Value, size: CGSize) {
        guard !ignoresDragUntilRelease else { return }

        if mode == nil {
            mode = .pending
            touchStart = value.startLocation
            path = []
            lineOpacity = 1
            holdTask = Task {
                try? await Task.sleep(for: Self.holdDuration)
                guard !Task.isCancelled, mode == .pending, let id = itemAt(touchStart, size) else { return }
                beginManipulating(id)
                mode = .moving
                onDragMoved(id, touchStart)
                liftCount += 1
            }
        }

        switch mode {
        case .pending:
            if hypot(value.location.x - touchStart.x, value.location.y - touchStart.y) > Self.moveTolerance {
                holdTask?.cancel()
                heading = .radians(atan2(value.location.y - touchStart.y, value.location.x - touchStart.x))
                distanceSinceSnip = 0
                path = [touchStart]
                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) { mode = .cutting }
                extendCut(to: value.location, size: size)
            }
        case .cutting:
            extendCut(to: value.location, size: size)
        case .moving:
            guard let id = manipulated, let base else { return }
            onMove(id, (base.centerX + value.translation.width / size.width,
                        base.centerY + value.translation.height / size.height,
                        base.width, base.rotation))
            onDragMoved(id, value.location)
        case .transforming, nil:
            break
        }
    }

    private func dragEnded(size: CGSize) {
        holdTask?.cancel()
        defer {
            ignoresDragUntilRelease = false
            if mode != .transforming { mode = nil }
        }
        guard !ignoresDragUntilRelease else { return }

        switch mode {
        case .cutting:
            finishCut(size: size)
        case .moving:
            if let id = manipulated, onDropInTrash(id) {
                manipulated = nil
                base = nil
            } else {
                commitManipulation()
            }
        default:
            break
        }
    }

    // MARK: - Two fingers

    private func transformChanged(_ value: SimultaneousGesture<MagnifyGesture, RotateGesture>.Value, size: CGSize) {
        if mode != .transforming {
            holdTask?.cancel()
            if mode == .moving {
                onCancelDrag()
                commitManipulation()
            }
            // A stroke already started is dropped, so nothing gets cut by accident.
            path = []
            ignoresDragUntilRelease = true
            mode = .transforming
            let start = value.first?.startLocation ?? value.second?.startLocation ?? touchStart
            if let id = itemAt(start, size) {
                beginManipulating(id)
            }
        }
        guard let id = manipulated, let base else { return }
        let width = value.first.map { base.width * $0.magnification } ?? base.width
        let rotation = value.second.map { base.rotation + $0.rotation.radians } ?? base.rotation
        onMove(id, (base.centerX, base.centerY, width, rotation))
    }

    private func transformEnded() {
        commitManipulation()
        mode = nil
    }

    // MARK: - Move / transform

    private func beginManipulating(_ id: UUID) {
        manipulated = id
        base = itemFrame(id)
        onSelect(id)
    }

    private func commitManipulation() {
        guard let id = manipulated else { return }
        onFinishMove(id)
        manipulated = nil
        base = nil
    }

    // MARK: - Cutting

    private func extendCut(to point: CGPoint, size: CGSize) {
        guard let last = path.last else { return }
        let step = hypot(point.x - last.x, point.y - last.y)
        guard step >= 1.5 else { return }
        path.append(point)

        // The scissors face the direction of travel, smoothed so they don't shake.
        let target = atan2(point.y - last.y, point.x - last.x)
        let current = heading.radians
        heading = .radians(current + atan2(sin(target - current), cos(target - current)) * 0.25)

        // "Snip" every ±24 pt while the tip is over a photo.
        if isOverPhoto(point, size) {
            distanceSinceSnip += step
            if distanceSinceSnip >= 24 {
                distanceSinceSnip = 0
                snipCount += 1
                withAnimation(.easeInOut(duration: 0.05)) { snipScale = 0.95 }
                Task {
                    try? await Task.sleep(for: .milliseconds(60))
                    withAnimation(.easeInOut(duration: 0.06)) { snipScale = 1 }
                }
            }
        }
    }

    private func finishCut(size: CGSize) {
        let didCut = path.count > 1 && onCut(path, size)
        withAnimation(.easeOut(duration: 0.2)) { mode = nil }
        if didCut {
            cutCount += 1
            path = []
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                lineOpacity = 0
            } completion: {
                if mode == nil {
                    path = []
                    lineOpacity = 1
                }
            }
        }
    }
}
