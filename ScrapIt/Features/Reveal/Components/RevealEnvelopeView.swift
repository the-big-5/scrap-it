import SwiftUI

/// Closed kraft envelope with the roll label (Figma 1323:41589, 1335:66589).
/// Swiping across the dashed tear guide slices it open with haptic ticks, or tapping opens it directly.
struct RevealEnvelopeView: View {
    let title: String
    let subtitle: String
    let isTorn: Bool
    /// `false` while photos are still developing: the strip only gives a little and springs back (change 024).
    var canTear = true
    /// Changes when new photos arrive: the envelope bounces and the count rolls up.
    var arrivalCount = 0
    let onTear: () -> Void

    @State private var stripDrag: CGFloat = 0
    @State private var sliceTickCount = 0
    @State private var lastTickDistance: CGFloat = 0
    @State private var lockedNudgeCount = 0
    @State private var lockedWiggleOffset: CGFloat = 0
    @State private var shimmerPhase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Envelope frame in Figma, before its −3° rotation.
    static let size = CGSize(width: 260, height: 340)
    /// The flap strip that tears off (Figma flap height).
    private static let stripHeight: CGFloat = 49
    private static let tearDistance: CGFloat = 110
    private static let sliceTickInterval: CGFloat = 20
    /// Translucent tear-guide pill dimensions from Figma `1335:66589` (`1515:27193`).
    private static let guidePillSize = CGSize(width: 285, height: 20)
    private static let guideSeamY: CGFloat = 47

    private var sliceProgress: CGFloat {
        guard canTear, !isTorn else { return 0 }
        return min(max(abs(stripDrag) / Self.tearDistance, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RevealEnvelopeArt(title: title, subtitle: subtitle)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: Self.size.height - Self.stripHeight)
                }

            // Progressive sliced slit and inner seam shadow revealed as the top flap peels back.
            if sliceProgress > 0 && !isTorn {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color(red: 61 / 255, green: 41 / 255, blue: 10 / 255).opacity(0.45))
                        .frame(width: max(12, (Self.size.width - 8) * sliceProgress), height: 2 + 2.5 * sliceProgress)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.28 * sliceProgress), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: Self.size.width - 12, height: 4 + 8 * sliceProgress)
                }
                .frame(width: Self.size.width, alignment: .center)
                .offset(y: Self.stripHeight - 1)
                .allowsHitTesting(false)
            }

            topTearSection
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture {
            handleEnvelopeTap()
        }
        .rotationEffect(.degrees(-3))
        .keyframeAnimator(initialValue: CGFloat(1), trigger: reduceMotion ? 0 : arrivalCount) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.05, duration: 0.14)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: sliceTickCount)
        .sensoryFeedback(.impact(weight: .heavy), trigger: isTorn)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.45), trigger: lockedNudgeCount)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Open roll envelope, \(title), \(subtitle)")
        .accessibilityHint(canTear ? "Swipe across the top or tap to tear open" : "Photos are still printing")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { handleEnvelopeTap() }
    }

    private var topTearSection: some View {
        ZStack(alignment: .topLeading) {
            RevealEnvelopeArt(title: title, subtitle: subtitle)
                .mask(alignment: .top) {
                    Rectangle().frame(height: Self.stripHeight)
                }
                .rotationEffect(.degrees(stripRotation), anchor: stripDrag >= 0 ? .bottomLeading : .bottomTrailing)
                .offset(x: stripOffset.width + lockedWiggleOffset, y: stripOffset.height)
                .opacity(isTorn ? 0 : 1)

            tearGuidePill
                .position(x: Self.size.width / 2, y: Self.guideSeamY)
                .rotationEffect(.degrees(stripRotation * 0.45), anchor: stripDrag >= 0 ? .bottomLeading : .bottomTrailing)
                .offset(x: stripOffset.width * 0.45 + lockedWiggleOffset, y: stripOffset.height * 0.5)
                .opacity(guidePillOpacity)
                .allowsHitTesting(false)

            if shouldShowSlidingPointer {
                slidingFingerHint
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            // Generous horizontal slice target covering both the flap strip and dashed guide pill.
            Color.clear
                .frame(width: Self.guidePillSize.width, height: 76)
                .contentShape(Rectangle())
                .gesture(tearGesture)
        }
    }

    private var guidePillOpacity: Double {
        if isTorn { return 0 }
        let base = canTear ? 1.0 : 0.45
        return max(0, base * (1 - Double(sliceProgress) * 0.35))
    }

    private var tearGuidePill: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 217 / 255, green: 217 / 255, blue: 217 / 255).opacity(0.6))

            // Single horizontal white dashed line (omitting Figma's accidental wrapped trailing dash).
            TearDashedLine()
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round, dash: [10, 8])
                )
                .padding(.horizontal, 16)

            if canTear && !isTorn && !reduceMotion {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.36)
                    .offset(x: shimmerPhase * width)
                }
                .clipShape(Capsule())
                .opacity(sliceProgress == 0 ? 1 : 0)
                .task(id: canTear && !isTorn) {
                    shimmerPhase = -0.45
                    withAnimation(.linear(duration: 1.9).repeatForever(autoreverses: false)) {
                        shimmerPhase = 1.15
                    }
                }
            }
        }
        .frame(width: Self.guidePillSize.width, height: Self.guidePillSize.height)
    }

    private var shouldShowSlidingPointer: Bool {
        canTear && !isTorn && !reduceMotion && stripDrag == 0
    }

    private var slidingFingerHint: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !shouldShowSlidingPointer)) { context in
            let cycle: Double = 2.2
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
            let pointer = Self.pointerFrame(at: t)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.45 * pointer.opacity))
                    .frame(width: 18, height: 18)
                    .position(x: pointer.x, y: Self.guideSeamY)

                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.45), radius: 3, y: 2)
                    .rotationEffect(.degrees(-12))
                    .scaleEffect(pointer.scale)
                    .opacity(pointer.opacity)
                    .position(x: pointer.x + 4, y: Self.guideSeamY + 16)
            }
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        }
    }

    static func pointerFrame(at t: Double) -> (x: CGFloat, opacity: Double, scale: CGFloat) {
        let startX: CGFloat = 44
        let endX: CGFloat = size.width - 44

        let opacity: Double
        if t < 0.14 {
            opacity = t / 0.14
        } else if t <= 0.78 {
            opacity = 1
        } else if t <= 0.90 {
            opacity = 1 - (t - 0.78) / 0.12
        } else {
            opacity = 0
        }

        let rawSlide = min(max((t - 0.14) / (0.78 - 0.14), 0), 1)
        let eased = rawSlide * rawSlide * (3 - 2 * rawSlide)
        let x = startX + (endX - startX) * CGFloat(eased)
        let scale: CGFloat = (t >= 0.14 && t <= 0.78) ? 0.94 : 1.04
        return (x, opacity, scale)
    }

    private var stripOffset: CGSize {
        if isTorn {
            return CGSize(width: stripDrag >= 0 ? 520 : -520, height: -160)
        }
        let lift = canTear ? -abs(stripDrag) * 0.14 : -abs(stripDrag) * 0.06
        return CGSize(width: stripDrag * 0.62, height: lift)
    }

    private var stripRotation: Double {
        if isTorn {
            return stripDrag >= 0 ? -35 : 35
        }
        return Double(-stripDrag / 8.5)
    }

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !isTorn else { return }
                let scaled = value.translation.width * (canTear ? 1 : 0.2)
                stripDrag = scaled
                if canTear {
                    let distance = abs(scaled)
                    if distance - lastTickDistance >= Self.sliceTickInterval && distance <= Self.tearDistance * 1.15 {
                        lastTickDistance = distance
                        sliceTickCount += 1
                    }
                }
            }
            .onEnded { value in
                guard !isTorn else { return }
                lastTickDistance = 0
                guard canTear else {
                    triggerLockedNudge()
                    return
                }
                let travel = value.predictedEndTranslation.width
                if abs(value.translation.width) > Self.tearDistance || abs(travel) > Self.tearDistance * 2 {
                    tear(direction: travel >= 0 ? 1 : -1)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        stripDrag = 0
                    }
                }
            }
    }

    private func handleEnvelopeTap() {
        guard !isTorn else { return }
        if canTear {
            tear(direction: 1)
        } else {
            triggerLockedNudge()
        }
    }

    private func triggerLockedNudge() {
        lockedNudgeCount += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            stripDrag = 0
        }
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.06)) { lockedWiggleOffset = 6 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(65))
            withAnimation(.easeInOut(duration: 0.06)) { lockedWiggleOffset = -5 }
            try? await Task.sleep(for: .milliseconds(65))
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) { lockedWiggleOffset = 0 }
        }
    }

    private func tear(direction: CGFloat) {
        lastTickDistance = 0
        withAnimation(.easeIn(duration: 0.35)) {
            stripDrag = direction * max(abs(stripDrag), 1)
            onTear()
        }
    }
}

private struct TearDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// The envelope layers exported from Figma (vectors) plus the paper label. The body's drop shadow is
/// clipped by the envelope frame in Figma, so none is drawn here either.
private struct RevealEnvelopeArt: View {
    let title: String
    let subtitle: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            layer("EnvelopeBody", width: 296, height: 376, x: -18, y: -4)
            layer("EnvelopeTextureA", width: 256.8, height: 339.5, x: 1.9, y: 1)
            layer("EnvelopeTextureB", width: 259.6, height: 336.3, x: 1, y: 1.7)
            layer("EnvelopeFlap", width: 261, height: 49, x: -0.5, y: -0.5)
            layer("EnvelopeFlapLine", width: 232, height: 2, x: 14, y: 47)
            layer("EnvelopeLeftEdge", width: 1.5, height: 294, x: 0.25, y: 36)
            layer("EnvelopeBottomFold", width: 237.2, height: 8.6, x: 11.4, y: 315.4)

            label
                .position(x: 130.3, y: 169.2)
        }
        .frame(width: RevealEnvelopeView.size.width, height: RevealEnvelopeView.size.height, alignment: .topLeading)
        .clipped()
    }

    private func layer(_ name: String, width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Image(name)
            .resizable()
            .frame(width: width, height: height)
            .offset(x: x, y: y)
            .accessibilityHidden(true)
    }

    /// Paper label (Figma "Label"): roll name 28 pt and photo count 16 pt, Architects Daughter.
    private var label: some View {
        VStack(spacing: 0) {
            Text(title)
                .dsTypography(DSTypographyToken(family: .architectsDaughter, weight: .regular, size: 28, lineHeight: 34))
                .foregroundStyle(DSColor.Brand.primary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: 196)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .dsTypography(DSTypography.Handwritten.normalRegular)
                .foregroundStyle(DSColor.Component.textSecondary.color)
                // The count rolls up like an odometer as photos arrive (change 024).
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: subtitle)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(minWidth: 139, minHeight: 77)
        .fixedSize()
        .background(DSColor.Paper.normal.color)
        .shadow(color: Color(red: 61 / 255, green: 41 / 255, blue: 10 / 255).opacity(0.3), radius: 2.5, y: 2)
        .rotationEffect(.degrees(-2))
    }
}
