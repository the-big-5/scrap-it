import SwiftUI

/// Knurled zoom wheel with discrete stepping based on `zoom-control-animation`.
/// Dragging left zooms in, dragging right zooms out across 36 discrete 0.1× steps (0.5× to 4.0×).
/// Features rigid mechanical hard endstops with silent boundary behavior (zero haptics at limits).
struct KnurledZoomWheelView: View {
    var capabilities: ZoomCapabilities
    var zoomFactor: CGFloat
    var isEnabled: Bool = true
    var onZoomChanged: (CGFloat) -> Void

    @State private var currentStop: ZoomStop = .standard
    @State private var isDragging = false
    @State private var lastDragLocationX: CGFloat = 0.0
    @State private var accumulatedDragTranslation: CGFloat = 0.0

    private let wheelWidth: CGFloat = 160
    private let wheelHeight: CGFloat = 60
    private let cornerRadius: CGFloat = 10
    private let ribCount = 14
    private let ribSpacing: CGFloat = 16
    private let dragPointsPerStep: CGFloat = 6.0

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

            // Horizontally Stepping Knurled Ribs (Moving underneath fixed aperture)
            ZStack {
                ForEach(-ribCount...ribCount, id: \.self) { index in
                    let baseX = CGFloat(index) * ribSpacing
                    let shiftedX = baseX + dynamicRibOffset
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
        .allowsHitTesting(isEnabled && capabilities.isZoomable)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    guard isEnabled && capabilities.isZoomable else { return }
                    if !isDragging {
                        isDragging = true
                        lastDragLocationX = value.location.x
                        accumulatedDragTranslation = 0.0
                    }
                    let deltaX = value.location.x - lastDragLocationX
                    lastDragLocationX = value.location.x
                    // Drag left zooms in (+), drag right zooms out (-)
                    accumulatedDragTranslation -= deltaX

                    let minStopIndex = ZoomStop.from(factor: Double(capabilities.minZoom)).stepIndex
                    let maxStopIndex = ZoomStop.from(factor: Double(capabilities.maxZoom)).stepIndex

                    var didChange = false
                    // Step immediately when crossing point threshold
                    while accumulatedDragTranslation >= dragPointsPerStep {
                        if currentStop.stepIndex < maxStopIndex {
                            let next = currentStop.nextClamped(maxStepIndex: maxStopIndex)
                            currentStop = next
                            HapticService.shared.playRatchetTick()
                            didChange = true
                            accumulatedDragTranslation -= dragPointsPerStep
                        } else {
                            // Reached upper boundary: silent hard stop (zero haptic)
                            accumulatedDragTranslation = 0.0
                            break
                        }
                    }

                    while accumulatedDragTranslation <= -dragPointsPerStep {
                        if currentStop.stepIndex > minStopIndex {
                            let prev = currentStop.previousClamped(minStepIndex: minStopIndex)
                            currentStop = prev
                            HapticService.shared.playRatchetTick()
                            didChange = true
                            accumulatedDragTranslation += dragPointsPerStep
                        } else {
                            // Reached lower boundary: silent hard stop (zero haptic)
                            accumulatedDragTranslation = 0.0
                            break
                        }
                    }

                    if didChange {
                        onZoomChanged(CGFloat(currentStop.rawValue))
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    accumulatedDragTranslation = 0.0
                }
        )
        .onAppear {
            syncStop(to: zoomFactor)
        }
        .onChange(of: zoomFactor) { _, newZoom in
            if !isDragging {
                syncStop(to: newZoom)
            }
        }
        .onChange(of: capabilities) { _, _ in
            syncStop(to: zoomFactor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera Zoom Wheel")
        .accessibilityValue(currentStop.displayValue)
        .accessibilityAdjustableAction { direction in
            let minStopIndex = ZoomStop.from(factor: Double(capabilities.minZoom)).stepIndex
            let maxStopIndex = ZoomStop.from(factor: Double(capabilities.maxZoom)).stepIndex
            switch direction {
            case .increment:
                if currentStop.stepIndex < maxStopIndex {
                    let next = currentStop.nextClamped(maxStepIndex: maxStopIndex)
                    currentStop = next
                    HapticService.shared.playRatchetTick()
                    onZoomChanged(CGFloat(next.rawValue))
                }
            case .decrement:
                if currentStop.stepIndex > minStopIndex {
                    let prev = currentStop.previousClamped(minStepIndex: minStopIndex)
                    currentStop = prev
                    HapticService.shared.playRatchetTick()
                    onZoomChanged(CGFloat(prev.rawValue))
                }
            @unknown default:
                break
            }
        }
    }

    /// Dynamic horizontal rib translation simulating analog cylinder rolling.
    /// Rotates left (- dynamicRibOffset) as zoom increases.
    private var dynamicRibOffset: CGFloat {
        let rotationAngle = currentStop.rotationAngleDegrees
        let translationPerDegree: CGFloat = ribSpacing / 18.0
        return -CGFloat(rotationAngle) * translationPerDegree
    }

    private func syncStop(to zoom: CGFloat) {
        let minStopIndex = ZoomStop.from(factor: Double(capabilities.minZoom)).stepIndex
        let maxStopIndex = ZoomStop.from(factor: Double(capabilities.maxZoom)).stepIndex
        let rawStop = ZoomStop.from(factor: Double(zoom))
        let clampedIndex = max(minStopIndex, min(maxStopIndex, rawStop.stepIndex))
        currentStop = ZoomStop.from(stepIndex: clampedIndex)
    }
}
