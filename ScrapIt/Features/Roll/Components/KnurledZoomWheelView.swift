import SwiftUI

/// Knurled zoom wheel (look from change 007). Behavior from change 008, modeled on sliding Camera Control:
/// drag **left** to zoom in, 0.1 steps over the phone's full zoom range, log scale, faster drags cover
/// more steps, light detents at lens values, hard endstops. Tap left / right jumps to the next lens value.
struct KnurledZoomWheelView: View {
    var capabilities: ZoomCapabilities
    var zoomFactor: CGFloat
    var isEnabled: Bool = true
    /// Drag: follows the finger.
    var onZoomChanged: (CGFloat) -> Void
    /// Tap: smooth jump to a lens value.
    var onLensSelected: (CGFloat) -> Void

    @State private var model = ZoomWheelModel(capabilities: .none)
    @State private var isDragging = false
    /// Resets by itself when the system cancels the drag, so the wheel never stays "held".
    @GestureState private var isFingerOnWheel = false
    @State private var lastTranslation: CGFloat = 0
    @State private var lastTickTime: Date = .distantPast
    @State private var animatedTravel: Double = 0

    private let wheelWidth: CGFloat = 160
    private let wheelHeight: CGFloat = 60
    private let cornerRadius: CGFloat = 10
    private let ribCount = 14
    private let ribSpacing: CGFloat = 16
    /// At most one tick per this interval, so fast drags do not buzz.
    private let minTickInterval: TimeInterval = 0.025

    var body: some View {
        ZStack {
            // Stationary Cylindrical Metallic Base
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(white: 0.12), location: 0.0),
                            .init(color: Color(white: 0.22), location: 0.22),
                            .init(color: Color(white: 0.42), location: 0.5),
                            .init(color: Color(white: 0.22), location: 0.78),
                            .init(color: Color(white: 0.12), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: wheelWidth, height: wheelHeight)

            // Horizontally rolling knurled ribs. Drawn from the continuous wheel travel so jumps
            // (Camera Control 0.1 steps, lens taps) animate as a real roll instead of aliasing.
            KnurledRibs(
                travel: isFingerOnWheel ? model.travel : animatedTravel,
                ribCount: ribCount,
                ribSpacing: ribSpacing,
                wheelWidth: wheelWidth
            )
            .frame(width: wheelWidth, height: wheelHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // Stationary Cylindrical Edge Shading / Vignette Overlay
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.55), location: 0.0),
                            .init(color: Color.clear, location: 0.18),
                            .init(color: Color.clear, location: 0.82),
                            .init(color: Color.black.opacity(0.55), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: wheelWidth, height: wheelHeight)

            // Fixed Outer Metallic Beveled Border
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(white: 0.4),
                            Color.black.opacity(0.9),
                            Color(white: 0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: wheelWidth, height: wheelHeight)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 4)
        .allowsHitTesting(isEnabled && model.isZoomable)
        .gesture(
            DragGesture(minimumDistance: 1)
                .updating($isFingerOnWheel) { _, state, _ in state = true }
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        lastTranslation = 0
                    }
                    let dx = value.translation.width - lastTranslation
                    lastTranslation = value.translation.width
                    let previousZoom = model.zoom
                    let update = model.drag(by: Double(dx), velocity: Double(value.velocity.width))
                    playHaptics(for: update)
                    animatedTravel = model.travel
                    if model.zoom != previousZoom {
                        onZoomChanged(model.zoom)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    animatedTravel = model.travel
                }
        )
        .onTapGesture { location in
            // Left side zooms in, like dragging left.
            jumpToLens(zoomingIn: location.x < wheelWidth / 2)
        }
        .onAppear {
            model = ZoomWheelModel(capabilities: capabilities, zoom: zoomFactor)
            animatedTravel = model.travel
        }
        .onChange(of: capabilities) { _, newCapabilities in
            model.update(capabilities: newCapabilities, zoom: zoomFactor)
            if !isFingerOnWheel {
                animatedTravel = model.travel
            }
        }
        .onChange(of: isFingerOnWheel) { _, onWheel in
            if !onWheel { isDragging = false }
        }
        .onChange(of: zoomFactor) { _, newZoom in
            // Follows zoom from elsewhere (Camera Control, flip) unless the finger is on the wheel.
            if !isFingerOnWheel, abs(newZoom - model.zoom) > 0.001 {
                let distance = abs(newZoom - model.zoom)
                let duration = max(0.12, min(0.65, Double(distance) * 0.15))
                model.sync(to: newZoom)
                withAnimation(.easeInOut(duration: duration)) {
                    animatedTravel = model.travel
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera Zoom Wheel")
        .accessibilityValue(ZoomCapabilities.label(for: model.zoom))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                jumpToLens(zoomingIn: true)
            case .decrement:
                jumpToLens(zoomingIn: false)
            @unknown default:
                break
            }
        }
    }

    private func playHaptics(for update: ZoomWheelModel.Update) {
        if update.hitEndstop {
            HapticService.shared.playHardStopThud()
        } else if update.hitLens {
            HapticService.shared.playSnapFeedback()
        } else if update.steps > 0, Date.now.timeIntervalSince(lastTickTime) >= minTickInterval {
            HapticService.shared.playRatchetTick()
            lastTickTime = .now
        }
    }

    private func jumpToLens(zoomingIn: Bool) {
        guard let lens = model.nextLens(zoomingIn: zoomingIn) else {
            HapticService.shared.playHardStopThud()
            return
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 1.0)) {
            model.sync(to: lens)
        }
        HapticService.shared.playSnapFeedback()
        onLensSelected(lens)
    }
}

/// The ribs of the wheel. `travel` is animatable, so SwiftUI interpolates the wheel position itself
/// (not the wrapped rib offset): a 0.1 zoom step rolls the ribs smoothly in the right direction.
private struct KnurledRibs: View, Animatable {
    var travel: Double
    let ribCount: Int
    let ribSpacing: CGFloat
    let wheelWidth: CGFloat

    var animatableData: Double {
        get { travel }
        set { travel = newValue }
    }

    var body: some View {
        let ribOffset = CGFloat(ZoomWheelModel.ribOffset(travel: travel, spacing: Double(ribSpacing)))
        ZStack {
            ForEach(-ribCount...ribCount, id: \.self) { index in
                let shiftedX = CGFloat(index) * ribSpacing + ribOffset
                let normalizedDistance = abs(shiftedX) / (wheelWidth / 2)

                if abs(shiftedX) < (wheelWidth / 2 + 10) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.85),
                                    Color(white: 0.08),
                                    Color.black.opacity(0.85)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 2.4, height: 50)
                        .opacity(max(0.18, 1.0 - pow(normalizedDistance, 2)))
                        .scaleEffect(x: max(0.65, 1.0 - (normalizedDistance * 0.25)), y: 1.0)
                        .offset(x: shiftedX)
                }
            }
        }
    }
}
