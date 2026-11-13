import SwiftUI

/// Pure interpolation math for pulling a spine off the shelf and turning it into a centered front cover.
enum BookPullOutMath {
    static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    static func size(progress: CGFloat, source: CGSize, target: CGSize) -> CGSize {
        let t = clamp(progress)
        return CGSize(
            width: source.width + (target.width - source.width) * t,
            height: source.height + (target.height - source.height) * t
        )
    }

    static func center(progress: CGFloat, source: CGPoint, target: CGPoint, arcLift: CGFloat = 18) -> CGPoint {
        let t = clamp(progress)
        let arc = sin(t * .pi) * arcLift
        return CGPoint(
            x: source.x + (target.x - source.x) * t,
            y: source.y + (target.y - source.y) * t - arc
        )
    }

    /// Swaps from spine to front cover just past the edge-on point of the pull-out turn.
    static func showsFrontCover(progress: CGFloat) -> Bool {
        clamp(progress) >= 0.42
    }

    /// Continuous Y-axis turn as the book rotates from facing spine-out (`0°`) toward facing cover-out (`0°`).
    static func yawDegrees(progress: CGFloat) -> Double {
        let t = Double(clamp(progress))
        let split = 0.42
        if t < split {
            return (t / split) * 88.0
        }
        return -88.0 + ((t - split) / (1.0 - split)) * 88.0
    }
}

/// Pure interpolation math for hinging a hardcover book open from its centered closed cover (`0`) to its centered
/// two-page spread (`1`) around the spine crease.
enum BookCoverHingeMath {
    static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    static func halfWidth(progress: CGFloat, closedWidth: CGFloat, openSpreadWidth: CGFloat) -> CGFloat {
        let t = clamp(progress)
        let targetHalf = openSpreadWidth / 2
        return closedWidth + (targetHalf - closedWidth) * t
    }

    static func bookHeight(progress: CGFloat, closedHeight: CGFloat, openSpreadHeight: CGFloat) -> CGFloat {
        let t = clamp(progress)
        return closedHeight + (openSpreadHeight - closedHeight) * t
    }

    /// Keeps the closed cover centered at `0` (`progress = 0`) and shifts the right half outward so the full open
    /// spread stays centered at `0` (`progress = 1`).
    static func rightHalfCenterOffsetX(progress: CGFloat, closedWidth: CGFloat, openSpreadWidth: CGFloat) -> CGFloat {
        let t = clamp(progress)
        let halfW = halfWidth(progress: t, closedWidth: closedWidth, openSpreadWidth: openSpreadWidth)
        return (halfW / 2) * t
    }

    static func hingeAngleDegrees(progress: CGFloat) -> Double {
        -180.0 * Double(clamp(progress))
    }

    static func showsInsideLeft(hingeAngleDegrees: Double) -> Bool {
        abs(hingeAngleDegrees) > 90.0
    }

    static func hingeShadowOpacity(progress: CGFloat) -> Double {
        sin(Double(clamp(progress)) * .pi) * 0.28
    }

    static func spreadRevealOpacity(progress: CGFloat) -> Double {
        Double(clamp((progress - 0.03) / 0.12))
    }
}

/// Shared textured hardcover backing used behind open two-page spreads (change 026 / 128).
struct BookCoverPlate: View {
    let colorHex: String
    var cornerRadius: CGFloat = 4.7

    var body: some View {
        ZStack {
            Color(coverHex: colorHex)
            Image("BookCoverTexture")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.55)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.black.opacity(0.3), lineWidth: max(cornerRadius * 1.49, 2))
                .blur(radius: max(cornerRadius * 1.49, 2))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .compositingGroup()
        .shadow(color: Color(red: 41 / 255, green: 26 / 255, blue: 10 / 255).opacity(0.35), radius: 2, y: 1)
    }
}

/// Reusable pull-out transition: lifts `spine` from `sourceRect` on the shelf and turns it 3D into `cover`
/// at `targetCenter` with `closedSize`, keeping both faces pre-mounted so GPU transforms stay silky smooth.
struct BookPullOutView<Spine: View, Cover: View>: View, Animatable {
    var progress: CGFloat
    let sourceRect: CGRect
    let targetCenter: CGPoint
    let closedSize: CGSize
    @ViewBuilder let spine: () -> Spine
    @ViewBuilder let cover: () -> Cover

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let clamped = BookPullOutMath.clamp(progress)
        let currentSize = BookPullOutMath.size(
            progress: clamped,
            source: sourceRect.size,
            target: closedSize
        )
        let center = BookPullOutMath.center(
            progress: clamped,
            source: CGPoint(x: sourceRect.midX, y: sourceRect.midY),
            target: targetCenter
        )
        let yaw = BookPullOutMath.yawDegrees(progress: clamped)
        let showCover = BookPullOutMath.showsFrontCover(progress: clamped)
        let baseSpineSize = CGSize(width: max(sourceRect.width, 1), height: max(sourceRect.height, 1))
        let baseClosedSize = CGSize(width: max(closedSize.width, 1), height: max(closedSize.height, 1))

        ZStack {
            spine()
                .frame(width: baseSpineSize.width, height: baseSpineSize.height)
                .scaleEffect(
                    x: currentSize.width / baseSpineSize.width,
                    y: currentSize.height / baseSpineSize.height
                )
                .opacity(showCover ? 0 : 1)

            cover()
                .frame(width: baseClosedSize.width, height: baseClosedSize.height)
                .scaleEffect(
                    x: currentSize.width / baseClosedSize.width,
                    y: currentSize.height / baseClosedSize.height
                )
                .opacity(showCover ? 1 : 0)
        }
        .frame(width: currentSize.width, height: currentSize.height)
        .rotation3DEffect(
            .degrees(yaw),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.45
        )
        .shadow(
            color: .black.opacity(0.18 + 0.14 * Double(clamped)),
            radius: 14,
            y: 8
        )
        .position(center)
    }
}

/// Reusable 3D book-opening transition: swings `frontCover` from closed (`openProgress = 0`) around its leading
/// spine edge (`-180°`) into a centered two-page spread (`openProgress = 1`) revealing `leftPage` and `rightPage`.
/// All three faces stay pre-mounted at constant sizes and scale via GPU transforms to avoid async image flicker.
struct BookCoverHingeView<FrontCover: View, LeftPage: View, RightPage: View>: View, Animatable {
    var openProgress: CGFloat
    let closedSize: CGSize
    let openSpreadSize: CGSize
    let coverHorizontalPadding: CGFloat
    let coverVerticalPadding: CGFloat
    let coverCornerRadius: CGFloat
    let coverColorHex: String
    @ViewBuilder let frontCover: () -> FrontCover
    @ViewBuilder let leftPage: () -> LeftPage
    @ViewBuilder let rightPage: () -> RightPage

    nonisolated var animatableData: CGFloat {
        get { openProgress }
        set { openProgress = newValue }
    }

    var body: some View {
        let p = BookCoverHingeMath.clamp(openProgress)
        let halfW = BookCoverHingeMath.halfWidth(
            progress: p,
            closedWidth: closedSize.width,
            openSpreadWidth: openSpreadSize.width
        )
        let bookH = BookCoverHingeMath.bookHeight(
            progress: p,
            closedHeight: closedSize.height,
            openSpreadHeight: openSpreadSize.height
        )
        let offsetX = BookCoverHingeMath.rightHalfCenterOffsetX(
            progress: p,
            closedWidth: closedSize.width,
            openSpreadWidth: openSpreadSize.width
        )
        let angle = BookCoverHingeMath.hingeAngleDegrees(progress: p)
        let showsInside = BookCoverHingeMath.showsInsideLeft(hingeAngleDegrees: angle)
        let shade = BookCoverHingeMath.hingeShadowOpacity(progress: p)
        let reveal = BookCoverHingeMath.spreadRevealOpacity(progress: p)

        let openHalfW = max(openSpreadSize.width / 2, 1)
        let openBookH = max(openSpreadSize.height, 1)
        let openPageW = max(openHalfW - coverHorizontalPadding, 1)
        let openPageH = max(openBookH - coverVerticalPadding * 2, 1)
        let baseClosedW = max(closedSize.width, 1)
        let baseClosedH = max(closedSize.height, 1)
        let insideScaleX = halfW / openHalfW
        let insideScaleY = bookH / openBookH
        let radius = coverCornerRadius

        ZStack {
            // Right half (sits stationary underneath the lifting cover leaf).
            ZStack(alignment: .leading) {
                halfCoverBacking(colorHex: coverColorHex, cornerRadius: radius, roundedTrailing: true)
                    .frame(width: openHalfW, height: openBookH)
                rightPage()
                    .frame(width: openPageW, height: openPageH)
                    .clipped()
                    .padding(.vertical, coverVerticalPadding)
                    .padding(.trailing, coverHorizontalPadding)
                Color.black.opacity(max(0, (1 - Double(p)) * 0.25))
                    .allowsHitTesting(false)
            }
            .frame(width: openHalfW, height: openBookH)
            .scaleEffect(x: insideScaleX, y: insideScaleY)
            .frame(width: halfW, height: bookH)
            .opacity(reveal)
            .offset(x: offsetX)

            // Front cover leaf rotating 0° → -180° around its leading spine edge.
            ZStack {
                ZStack(alignment: .trailing) {
                    halfCoverBacking(colorHex: coverColorHex, cornerRadius: radius, roundedTrailing: false)
                        .frame(width: openHalfW, height: openBookH)
                    leftPage()
                        .frame(width: openPageW, height: openPageH)
                        .clipped()
                        .padding(.vertical, coverVerticalPadding)
                        .padding(.leading, coverHorizontalPadding)
                }
                .frame(width: openHalfW, height: openBookH)
                .scaleEffect(x: -insideScaleX, y: insideScaleY)
                .frame(width: halfW, height: bookH)
                .opacity(showsInside ? 1 : 0)

                frontCover()
                    .frame(width: baseClosedW, height: baseClosedH)
                    .scaleEffect(x: halfW / baseClosedW, y: bookH / baseClosedH)
                    .frame(width: halfW, height: bookH)
                    .opacity(showsInside ? 0 : 1)

                Color.black.opacity(shade * 0.55)
                    .allowsHitTesting(false)
            }
            .frame(width: halfW, height: bookH)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.45
            )
            .shadow(
                color: .black.opacity(shade * 1.15),
                radius: 10,
                x: CGFloat(-sin(angle * .pi / 180)) * 6
            )
            .offset(x: offsetX)
        }
        .frame(width: max(closedSize.width, openSpreadSize.width), height: max(closedSize.height, openSpreadSize.height))
    }

    private func halfCoverBacking(colorHex: String, cornerRadius: CGFloat, roundedTrailing: Bool) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: roundedTrailing ? 0 : cornerRadius,
            bottomLeadingRadius: roundedTrailing ? 0 : cornerRadius,
            bottomTrailingRadius: roundedTrailing ? cornerRadius : 0,
            topTrailingRadius: roundedTrailing ? cornerRadius : 0
        )
        return ZStack {
            Color(coverHex: colorHex)
            Image("BookCoverTexture")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.55)
        }
        .clipShape(shape)
        .shadow(color: Color(red: 41 / 255, green: 26 / 255, blue: 10 / 255).opacity(0.32), radius: 2, y: 1)
    }
}
