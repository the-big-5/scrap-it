import SwiftUI
import UIKit

/// Circular analog shots-left dial element (change 041, change 055, change 059) matching Figma nodes 1302:47951 / 1300:33812.
/// Displays remaining shots count as an analogue odometer drum with independent scrolling digit tumblers.
struct ShotsLeftDialView: View {
    let shotsRemaining: Int
    var totalShots: Int = 36

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

    var aboveShots: Int? {
        safeShots < totalShots ? safeShots + 1 : nil
    }

    var belowShots: Int {
        max(0, safeShots - 1)
    }

    var aboveTensDigit: Int? {
        aboveShots.map { ($0 / 10) % 10 }
    }

    var aboveOnesDigit: Int? {
        aboveShots.map { $0 % 10 }
    }

    var belowTensDigit: Int {
        (belowShots / 10) % 10
    }

    var belowOnesDigit: Int {
        belowShots % 10
    }

    var isTensBlankAbove: Bool {
        aboveTensDigit == nil
    }

    var isOnesBlankAbove: Bool {
        aboveOnesDigit == nil
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
                    OdometerDigitWheelView(
                        digit: tensDigit,
                        aboveDigit: aboveTensDigit,
                        belowDigit: belowTensDigit
                    )
                    OdometerDigitWheelView(
                        digit: onesDigit,
                        aboveDigit: aboveOnesDigit,
                        belowDigit: belowOnesDigit
                    )
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
    let aboveDigit: Int?
    let belowDigit: Int

    @State private var progress: Double = 0.0
    @State private var isScrolling: Bool = false
    @State private var previousDigit: Int
    @State private var oldAboveDigit: Int?
    @State private var oldCurrentDigit: Int
    @State private var animTask: Task<Void, Never>?

    private static let slotHeight: CGFloat = 19

    init(digit: Int, aboveDigit: Int?, belowDigit: Int) {
        self.digit = digit
        self.aboveDigit = aboveDigit
        self.belowDigit = belowDigit
        _previousDigit = State(initialValue: digit)
        _oldCurrentDigit = State(initialValue: digit)
        _oldAboveDigit = State(initialValue: aboveDigit)
    }

    var body: some View {
        OdometerDrumWheel(
            progress: progress,
            slotHeight: Self.slotHeight,
            isScrolling: isScrolling,
            restingAbove: aboveDigit,
            restingCurrent: digit,
            restingBelow: belowDigit,
            scrollOldAbove: oldAboveDigit,
            scrollOldCurrent: oldCurrentDigit,
            scrollNewCurrent: digit,
            scrollBelow: belowDigit
        )
        .onChange(of: digit) { oldVal, newVal in
            guard newVal != oldVal else { return }

            if newVal == (oldVal - 1 + 10) % 10 {
                animTask?.cancel()
                oldCurrentDigit = oldVal
                isScrolling = true
                progress = 0.0

                withAnimation(.easeInOut(duration: 0.25)) {
                    progress = 1.0
                }

                animTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 260_000_000)
                    guard !Task.isCancelled else { return }
                    isScrolling = false
                    progress = 0.0
                    previousDigit = newVal
                    oldAboveDigit = aboveDigit
                }
            } else {
                animTask?.cancel()
                isScrolling = false
                progress = 0.0
                previousDigit = newVal
                oldAboveDigit = aboveDigit
                oldCurrentDigit = newVal
            }
        }
        .onChange(of: aboveDigit) { _, newAbove in
            if !isScrolling {
                oldAboveDigit = newAbove
            }
        }
    }
}

// MARK: - Odometer Drum Wheel (Animatable)

private struct OdometerDrumWheel: View, Animatable {
    var progress: Double
    let slotHeight: CGFloat
    let isScrolling: Bool

    let restingAbove: Int?
    let restingCurrent: Int
    let restingBelow: Int

    let scrollOldAbove: Int?
    let scrollOldCurrent: Int
    let scrollNewCurrent: Int
    let scrollBelow: Int

    private static let creamText = Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255)

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ZStack {
            if isScrolling {
                // 1. Exiting top digit (old above)
                if let oldAbove = scrollOldAbove {
                    let y = -slotHeight - CGFloat(progress) * slotHeight
                    let opacity = max(0.0, 0.35 * (1.0 - progress))
                    digitText(oldAbove, scale: 0.75, opacity: opacity, y: y)
                }

                // 2. Old center digit moving to top
                let yOld = -CGFloat(progress) * slotHeight
                let scaleOld = 1.0 - (0.25 * progress)
                let opacityOld = 1.0 - (0.65 * progress)
                digitText(scrollOldCurrent, scale: scaleOld, opacity: opacityOld, y: yOld)

                // 3. New center digit entering from bottom
                let yNew = slotHeight - CGFloat(progress) * slotHeight
                let scaleNew = 0.75 + (0.25 * progress)
                let opacityNew = 0.35 + (0.65 * progress)
                digitText(scrollNewCurrent, scale: scaleNew, opacity: opacityNew, y: yNew)

                // 4. Entering bottom digit
                let yBelow = (2.0 * slotHeight) - CGFloat(progress) * slotHeight
                let opacityBelow = 0.35 * progress
                digitText(scrollBelow, scale: 0.75, opacity: opacityBelow, y: yBelow)
            } else {
                // Resting state
                if let above = restingAbove {
                    digitText(above, scale: 0.75, opacity: 0.35, y: -slotHeight)
                }
                digitText(restingCurrent, scale: 1.0, opacity: 1.0, y: 0)
                digitText(restingBelow, scale: 0.75, opacity: 0.35, y: slotHeight)
            }
        }
        .frame(width: 14, height: 50)
    }

    private func digitText(_ digit: Int, scale: Double, opacity: Double, y: CGFloat) -> some View {
        Text("\(digit)")
            .font(.system(size: 20, weight: .semibold).monospacedDigit())
            .foregroundStyle(Self.creamText)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: y)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var shots = 24
        private let totalShots = 24

        var body: some View {
            VStack(spacing: 24) {
                ShotsLeftDialView(shotsRemaining: shots, totalShots: totalShots)

                HStack(spacing: 16) {
                    Button("Capture (-1)") {
                        if shots > 0 { shots -= 1 }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset (24)") {
                        shots = 24
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
