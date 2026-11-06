import SwiftUI

struct KnurledZoomWheelView: View {
    var zoomFactor: CGFloat
    var onZoomChanged: (CGFloat) -> Void

    @State private var currentStop: ZoomStop = .standard
    @State private var continuousIndex: Double = 1.0
    @State private var isDragging: Bool = false
    @State private var dragStartIndex: Double = 0.0
    @State private var lastTickIndex: Double = 1.0
    @State private var hasFiredEndstop: Bool = false

    private let wheelWidth: CGFloat = 172
    private let wheelHeight: CGFloat = 44
    private let cornerRadius: CGFloat = 10
    private let ribCount = 14
    private let ribSpacing: CGFloat = 16

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

            // Horizontally Rolling Knurled Ribs
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
                            .frame(width: 2.4, height: 34)
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
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartIndex = continuousIndex
                        lastTickIndex = continuousIndex
                        hasFiredEndstop = false
                    }
                    let deltaIndex = Double(value.translation.width / 70.0)
                    let unclamped = dragStartIndex + deltaIndex
                    let clamped = max(0.0, min(2.0, unclamped))

                    // Micro-tick for knurled rib translation
                    if abs(clamped - lastTickIndex) >= 0.08 {
                        HapticService.shared.playRatchetTick()
                        lastTickIndex = clamped
                    }

                    // Firm mechanical endstop thud on boundary collision (no rubber-banding)
                    if unclamped < 0.0 || unclamped > 2.0 {
                        if !hasFiredEndstop {
                            HapticService.shared.playHardStopThud()
                            hasFiredEndstop = true
                        }
                    } else {
                        hasFiredEndstop = false
                    }

                    continuousIndex = clamped
                    let newStop = ZoomStop.closestFromSliderIndex(clamped)
                    if newStop != currentStop {
                        currentStop = newStop
                        HapticService.shared.playSnapFeedback()
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    hasFiredEndstop = false
                    withAnimation(.spring(response: 0.28, dampingFraction: 1.0)) {
                        continuousIndex = currentStop.sliderIndex
                    }
                    onZoomChanged(CGFloat(currentStop.rawValue))
                }
        )
        .onTapGesture { location in
            handleTap(at: location)
        }
        .onAppear {
            syncFromZoomFactor(zoomFactor, animated: false)
        }
        .onChange(of: zoomFactor) { _, newZoom in
            if !isDragging {
                syncFromZoomFactor(newZoom, animated: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera Zoom Wheel")
        .accessibilityValue(currentStop.displayValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                stepUp()
            case .decrement:
                stepDown()
            @unknown default:
                break
            }
        }
    }

    private var dynamicRibOffset: CGFloat {
        let rotationAngle = ZoomStop.interpolatedAngle(forSliderIndex: continuousIndex)
        let translationPerDegree: CGFloat = ribSpacing / 18.0
        return CGFloat(rotationAngle) * translationPerDegree
    }

    private func handleTap(at location: CGPoint) {
        if location.x > (wheelWidth / 2) {
            stepUp()
        } else {
            stepDown()
        }
    }

    private func stepUp() {
        let next = currentStop.nextClamped()
        guard next != currentStop else {
            HapticService.shared.playHardStopThud()
            return
        }
        currentStop = next
        withAnimation(.spring(response: 0.28, dampingFraction: 1.0)) {
            continuousIndex = next.sliderIndex
        }
        HapticService.shared.playSnapFeedback()
        onZoomChanged(CGFloat(next.rawValue))
    }

    private func stepDown() {
        let prev = currentStop.previousClamped()
        guard prev != currentStop else {
            HapticService.shared.playHardStopThud()
            return
        }
        currentStop = prev
        withAnimation(.spring(response: 0.28, dampingFraction: 1.0)) {
            continuousIndex = prev.sliderIndex
        }
        HapticService.shared.playSnapFeedback()
        onZoomChanged(CGFloat(prev.rawValue))
    }

    private func syncFromZoomFactor(_ factor: CGFloat, animated: Bool) {
        let matchingStop = ZoomStop.closest(to: Double(factor))
        currentStop = matchingStop
        if animated {
            withAnimation(.spring(response: 0.28, dampingFraction: 1.0)) {
                continuousIndex = matchingStop.sliderIndex
            }
        } else {
            continuousIndex = matchingStop.sliderIndex
        }
    }
}
