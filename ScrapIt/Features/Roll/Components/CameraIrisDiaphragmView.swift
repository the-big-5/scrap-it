import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Analog mechanical iris diaphragm with 8 overlapping aperture blades that constrict
/// inward to black when closing and dilate outward when opening, accompanied by mechanical haptics.
struct CameraIrisDiaphragmView: View {
    let isClosed: Bool

    @State private var animProgress: CGFloat = 0.0

    var body: some View {
        IrisBladesCanvas(progress: animProgress)
            .allowsHitTesting(false)
            .onAppear {
                animProgress = isClosed ? 1.0 : 0.0
            }
            .onChange(of: isClosed) { _, closed in
                if closed {
                    playRatchetHaptic()
                    withAnimation(.easeIn(duration: 0.18)) {
                        animProgress = 1.0
                    }
                } else {
                    playOpeningHaptic()
                    withAnimation(.easeOut(duration: 0.22)) {
                        animProgress = 0.0
                    }
                }
            }
    }

    // MARK: - Haptics

    private func playRatchetHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            generator.impactOccurred(intensity: 0.8)
            try? await Task.sleep(nanoseconds: 60_000_000)
            generator.impactOccurred(intensity: 0.5)
        }
        #endif
    }

    private func playOpeningHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 70_000_000)
            generator.impactOccurred(intensity: 0.6)
        }
        #endif
    }
}

// MARK: - Animatable Canvas

private struct IrisBladesCanvas: View, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            guard progress > 0.001 else { return }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let halfWidth = size.width / 2
            let halfHeight = size.height / 2
            let diagRadius = sqrt(halfWidth * halfWidth + halfHeight * halfHeight)
            let maxRadius = diagRadius * 1.35
            let outerRadius = diagRadius * 1.8

            let currentRadius = max(0, maxRadius * (1.0 - progress))
            let bladeCount = 8
            let angleStep = (CGFloat.pi * 2) / CGFloat(bladeCount)
            let rotationAngle = progress * (CGFloat.pi / 4.5) // ~40 degrees mechanical twist
            let overlap: CGFloat = 0.005 // Minimal overlap to eliminate subpixel antialiasing gaps

            // Draw 8 equal aperture blade triangles circularly
            for i in 0..<bladeCount {
                let baseAngle = CGFloat(i) * angleStep
                let nextAngle = CGFloat(i + 1) * angleStep

                let startAngle = baseAngle + rotationAngle - overlap
                let endAngle = nextAngle + rotationAngle + overlap

                let innerPoint1 = CGPoint(
                    x: center.x + currentRadius * cos(startAngle),
                    y: center.y + currentRadius * sin(startAngle)
                )
                let innerPoint2 = CGPoint(
                    x: center.x + currentRadius * cos(endAngle),
                    y: center.y + currentRadius * sin(endAngle)
                )

                let outerPoint2 = CGPoint(
                    x: center.x + outerRadius * cos(endAngle),
                    y: center.y + outerRadius * sin(endAngle)
                )
                let outerPoint1 = CGPoint(
                    x: center.x + outerRadius * cos(startAngle),
                    y: center.y + outerRadius * sin(startAngle)
                )

                var path = Path()
                path.move(to: innerPoint1)
                path.addLine(to: innerPoint2)
                path.addLine(to: outerPoint2)
                path.addLine(to: outerPoint1)
                path.closeSubpath()

                // Metallic blade shading alternating subtle tonality
                let tone: Double = (i % 2 == 0) ? 0.08 : 0.12
                let bladeColor = Color(red: tone, green: tone * 0.95, blue: tone * 0.9)
                let bladeDark = Color(red: 0.03, green: 0.03, blue: 0.03)

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [bladeColor, bladeDark]),
                        startPoint: innerPoint1,
                        endPoint: outerPoint2
                    )
                )

                // Radial blade edge separation line
                var radialEdge = Path()
                radialEdge.move(to: innerPoint1)
                radialEdge.addLine(to: outerPoint1)
                context.stroke(
                    radialEdge,
                    with: .color(Color(white: 0.22).opacity(0.6)),
                    lineWidth: 1.0
                )

                // Leading knife edge highlight when aperture is open
                if currentRadius > 1.0 {
                    var edgePath = Path()
                    edgePath.move(to: innerPoint1)
                    edgePath.addLine(to: innerPoint2)
                    context.stroke(
                        edgePath,
                        with: .color(Color(white: 0.28).opacity(0.85)),
                        lineWidth: 1.2
                    )
                }
            }

            // Central seal point when fully closed to ensure zero light leakage
            if progress > 0.96 {
                let sealPath = Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6))
                context.fill(sealPath, with: .color(Color(white: 0.04)))
            }
        }
    }
}
