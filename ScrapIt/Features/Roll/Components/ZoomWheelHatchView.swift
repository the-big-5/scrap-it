import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Dual horizontal sliding metallic hatch doors that cover the knurled zoom wheel on front camera,
/// and park visibly on the left and right sides of the wheel with comfortable margins on back camera.
struct ZoomWheelHatchView: View {
    let isClosed: Bool

    // Geometry matching shifted top plate layout:
    // Zoom wheel slot: center x = 585 (width = 172, spans x: 499 to 671)
    // Margin between wheel and covers on open state = 14 pt
    // Slide distance = 86 (door width) + 14 (margin) = 100 pt
    //
    // Left door (width 86, height 83):
    //   - Open: center x = 442 (spans x: 399 to 485, leaving 14 pt margin before wheel at 499)
    //   - Closed: center x = 542 (spans x: 499 to 585, covers left half of wheel)
    // Right door (width 86, height 83):
    //   - Open: center x = 728 (spans x: 685 to 771, leaving 14 pt margin after wheel at 671, and 18 pt before Info button at 789)
    //   - Closed: center x = 628 (spans x: 585 to 671, covers right half of wheel)
    private let doorWidth: CGFloat = 86
    private let doorHeight: CGFloat = 83

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Left Sliding Door (parks at x: 399..485 when open; covers x: 499..585 when closed)
            HatchDoor(side: .left)
                .frame(width: doorWidth, height: doorHeight)
                .position(x: isClosed ? 542 : 442, y: doorHeight / 2)

            // Right Sliding Door (complete rectangular block; parks at x: 685..771 when open; covers x: 585..671 when closed)
            HatchDoor(side: .right)
                .frame(width: doorWidth, height: doorHeight)
                .position(x: isClosed ? 628 : 728, y: doorHeight / 2)
        }
        .frame(width: 875, height: doorHeight)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.34, dampingFraction: 0.8), value: isClosed)
        .onChange(of: isClosed) { _, closed in
            playHatchHaptic(isClosing: closed)
        }
    }

    // MARK: - Haptic Feedback

    private func playHatchHaptic(isClosing: Bool) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: isClosing ? .medium : .light)
        generator.prepare()
        generator.impactOccurred(intensity: isClosing ? 0.85 : 0.65)
        #endif
    }
}

// MARK: - Hatch Door Component

private struct HatchDoor: View {
    enum Side {
        case left
        case right
    }

    let side: Side

    var body: some View {
        ZStack {
            // Metallic Gradient matching Top Plate
            LinearGradient(
                stops: [
                    .init(color: Color(red: 42 / 255, green: 36 / 255, blue: 31 / 255), location: 0.0),
                    .init(color: Color(red: 23 / 255, green: 23 / 255, blue: 23 / 255), location: 0.55),
                    .init(color: Color(red: 42 / 255, green: 36 / 255, blue: 31 / 255), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Top highlight & bottom shadow bevels
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(height: 2)
            }

            // Mechanical stamped vertical rib grooves
            HStack(spacing: 5) {
                ForEach(0..<3) { _ in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 1, height: 32)
                        Rectangle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 1, height: 32)
                    }
                }
            }

            // Outer edge and center seam accents
            HStack(spacing: 0) {
                if side == .left {
                    Rectangle()
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 1)
                    Spacer()
                    Rectangle()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 1.5)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 1.2)
                    Spacer()
                    Rectangle()
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 1)
                }
            }
        }
        .frame(width: 86, height: 83)
        .shadow(color: Color.black.opacity(0.4), radius: 3, x: side == .left ? -2 : 2, y: 0)
    }
}
