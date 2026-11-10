import SwiftUI

/// Closed kraft envelope with the roll label (Figma 1323:41589). Swiping across the top strip tears it off.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Envelope frame in Figma, before its −3° rotation.
    static let size = CGSize(width: 260, height: 340)
    /// The flap strip that tears off (Figma flap height).
    private static let stripHeight: CGFloat = 49
    private static let tearDistance: CGFloat = 110

    var body: some View {
        ZStack(alignment: .topLeading) {
            RevealEnvelopeArt(title: title, subtitle: subtitle)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: Self.size.height - Self.stripHeight)
                }

            RevealEnvelopeArt(title: title, subtitle: subtitle)
                .mask(alignment: .top) {
                    Rectangle().frame(height: Self.stripHeight)
                }
                .rotationEffect(.degrees(stripRotation), anchor: stripDrag >= 0 ? .bottomLeading : .bottomTrailing)
                .offset(x: stripOffset.width, y: stripOffset.height)
                .opacity(isTorn ? 0 : 1)
                .gesture(tearGesture)
                .accessibilityElement()
                .accessibilityLabel("Tear open the envelope")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { if canTear { tear(direction: 1) } }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .rotationEffect(.degrees(-3))
        .keyframeAnimator(initialValue: CGFloat(1), trigger: reduceMotion ? 0 : arrivalCount) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.05, duration: 0.14)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: isTorn)
    }

    private var stripOffset: CGSize {
        if isTorn {
            return CGSize(width: stripDrag >= 0 ? 520 : -520, height: -160)
        }
        return CGSize(width: stripDrag * 0.6, height: -abs(stripDrag) * 0.12)
    }

    private var stripRotation: Double {
        if isTorn {
            return stripDrag >= 0 ? -35 : 35
        }
        return Double(-stripDrag / 10)
    }

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !isTorn else { return }
                stripDrag = value.translation.width * (canTear ? 1 : 0.2)
            }
            .onEnded { value in
                guard !isTorn else { return }
                guard canTear else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { stripDrag = 0 }
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

    private func tear(direction: CGFloat) {
        withAnimation(.easeIn(duration: 0.35)) {
            stripDrag = direction * max(abs(stripDrag), 1)
            onTear()
        }
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
