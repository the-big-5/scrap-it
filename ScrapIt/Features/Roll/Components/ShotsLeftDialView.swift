import SwiftUI
import UIKit

/// Circular analog shots-left dial element (change 041, change 055) matching Figma nodes 1302:47951 / 1300:33812.
/// Displays remaining shots count as an analogue odometer drum with independent scrolling digit tumblers.
struct ShotsLeftDialView: View {
    let shotsRemaining: Int

    private static let creamText = Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255)

    @State private var previousShots: Int?
    @State private var hapticTask: Task<Void, Never>?

    var safeShots: Int {
        max(0, shotsRemaining)
    }

    var tensDigit: Int {
        (safeShots / 10) % 10
    }

    var onesDigit: Int {
        safeShots % 10
    }

    var body: some View {
        ZStack {
            // Outer Dial Housing from Figma (with drop shadows and embossed rim)
            Image("CameraDialOuter")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 118, height: 118)

            // Inner Recessed Drum (Figma 1302:47954, 55.865pt diameter)
            ZStack {
                Image("CameraDialInner")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)

                // Mechanical odometer tumbler wheels
                HStack(spacing: 1) {
                    OdometerDigitWheelView(digit: tensDigit)
                    OdometerDigitWheelView(digit: onesDigit)
                }
                .frame(width: 50, height: 50)
                .clipped()
            }
            .frame(width: 56, height: 56)
        }
        .frame(width: 83, height: 83)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shotsRemaining) shots left")
        .onAppear {
            previousShots = safeShots
        }
        .onChange(of: safeShots) { oldVal, newVal in
            hapticTask?.cancel()
            if newVal == oldVal - 1 {
                hapticTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard !Task.isCancelled else { return }
                    let feedback = UIImpactFeedbackGenerator(style: .light)
                    feedback.prepare()
                    feedback.impactOccurred()
                }
            }
            previousShots = newVal
        }
        .onDisappear {
            hapticTask?.cancel()
        }
    }
}

// MARK: - Mechanical Odometer Digit Wheel

private struct OdometerDigitWheelView: View {
    let digit: Int

    @State private var position: Double
    @State private var previousDigit: Int

    private static let slotHeight: CGFloat = 19

    init(digit: Int) {
        self.digit = digit
        _position = State(initialValue: Double(digit))
        _previousDigit = State(initialValue: digit)
    }

    var body: some View {
        OdometerDrumWheel(position: position, slotHeight: Self.slotHeight)
            .onChange(of: digit) { _, newDigit in
                let oldDigit = previousDigit
                previousDigit = newDigit

                guard newDigit != oldDigit else { return }

                // Decrement scroll (e.g. 4 -> 3 or 0 -> 9): drum rolls upwards
                if newDigit == (oldDigit - 1 + 10) % 10 {
                    let targetPosition = position - 1.0
                    withAnimation(.easeInOut(duration: 0.25)) {
                        position = targetPosition
                    }
                } else {
                    // Non-sequential change (reset/initialization): snap directly
                    position = Double(newDigit)
                }
            }
    }
}

// MARK: - Odometer Drum Wheel (Animatable)

private struct OdometerDrumWheel: View, Animatable {
    var position: Double
    let slotHeight: CGFloat

    private static let creamText = Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255)

    var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let y = yOffset(for: i, scrollPosition: position)
                let distance = abs(y)
                if distance <= slotHeight * 2.2 {
                    let normalized = distance / slotHeight
                    let scale = max(0.75, 1.0 - (0.25 * min(1.0, normalized)))
                    let opacity: Double = if normalized <= 1.0 {
                        1.0 - (0.65 * normalized)
                    } else {
                        max(0.0, 0.35 * (2.0 - normalized))
                    }

                    Text("\(i)")
                        .font(.system(size: 20, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Self.creamText)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .offset(y: y)
                }
            }
        }
        .frame(width: 14, height: 50)
    }

    private func yOffset(for digitIndex: Int, scrollPosition: Double) -> CGFloat {
        var diff = (Double(digitIndex) - scrollPosition).truncatingRemainder(dividingBy: 10)
        if diff > 5 { diff -= 10 }
        if diff < -5 { diff += 10 }
        return CGFloat(-diff * Double(slotHeight))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var shots = 24

        var body: some View {
            VStack(spacing: 24) {
                ShotsLeftDialView(shotsRemaining: shots)

                HStack(spacing: 16) {
                    Button("Capture (-1)") {
                        if shots > 0 { shots -= 1 }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset (36)") {
                        shots = 36
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(40)
            .background(Color(red: 20 / 255, green: 20 / 255, blue: 22 / 255))
        }
    }

    return PreviewWrapper()
}
