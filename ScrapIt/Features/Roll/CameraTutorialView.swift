import SwiftUI
import TipKit

/// The camera tutorial after "Let's Try It" (change 152; Figma portrait 1545:36476…36886, 1545:37396, landscape
/// 1545:37750…38070): the capture camera body without Back / End Roll, a Skip tab, tips over a dimmed screen with
/// the explained control left bright, the "Try it Out" card, two practice shots, then "Let's get scrapbooking".
/// Tips, cards and Skip turn with the phone like the camera's symbols.
struct CameraTutorialView: View {
    /// Skip, or "Open Scrapbook" until the scrapbook tutorial exists: on to Welcome.
    let onFinish: () -> Void

    @State private var viewModel = CameraTutorialViewModel()
    @State private var deviceOrientation: RollCameraOrientation.DeviceOrientation = .landscapeLeft
    @State private var landscapeSide: RollCameraOrientation.LandscapeSide = .left
    @State private var zoomTextRotation: Double = 0

    private var camera: CameraController { viewModel.camera }

    var body: some View {
        CameraStage(
            camera: camera,
            deviceOrientation: $deviceOrientation,
            landscapeSide: $landscapeSide,
            zoomTextRotation: $zoomTextRotation,
            onAppear: {
                camera.setFilter(.colorPrint200)
                Task { await camera.startSession() }
            },
            onDisappear: { camera.stopSession() },
            canvas: {
                CameraBodyView(
                    camera: camera,
                    deviceOrientation: deviceOrientation,
                    zoomTextRotation: zoomTextRotation,
                    shotsRemaining: viewModel.shotsRemaining,
                    totalShots: CameraTutorialViewModel.totalShots,
                    onShutter: { Task { await viewModel.shutterTapped() } }
                )
                .allowsHitTesting(viewModel.areControlsEnabled)
            },
            overlay: { _ in EmptyView() }
        )
        .overlayPreferenceValue(CameraControlAnchorsKey.self) { anchors in
            GeometryReader { proxy in
                let screen = proxy.size
                let angle = userAngle(isPortraitWindow: screen.height > screen.width)
                let user = UserSpace(screen: screen, angle: angle)
                ZStack {
                    if let tip = viewModel.currentTip, let anchor = anchors[tip.control] {
                        let hole = proxy[anchor].insetBy(dx: -8, dy: -8)
                        dim(opacity: 0.55, hole: hole, cornerRadius: holeCornerRadius(for: tip.control, in: hole), screen: screen)
                        user.place {
                            tipBubble(tip, pointingAt: user.rect(from: hole), in: user.size)
                        }
                    }
                    switch viewModel.step {
                    case .tryItOut:
                        user.place { tryItOutCard }
                    case .finished:
                        user.place { finishedCard }
                    case .tip, .shooting:
                        EmptyView()
                    }
                    user.place { skipTab }
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.step)
                .animation(.easeInOut(duration: 0.3), value: deviceOrientation)
            }
            .ignoresSafeArea()
        }
        .statusBarHidden()
    }

    /// Like the capture pop-ups: upright for the phone as it's held.
    private func userAngle(isPortraitWindow: Bool) -> Double {
        isPortraitWindow
            ? RollCameraOrientation.cameraReturnAngle(deviceOrientation: deviceOrientation)
            : RollCameraOrientation.symbolRotationDegrees(for: deviceOrientation)
    }

    private func holeCornerRadius(for control: CameraControl, in hole: CGRect) -> CGFloat {
        switch control {
        case .shotsLeft, .flip, .shutter: min(hole.width, hole.height) / 2
        case .flash: 26
        case .zoom: 18
        }
    }

    /// The dimmed screen with a bright cut-out around the explained control; a tap anywhere goes on.
    private func dim(opacity: Double, hole: CGRect, cornerRadius: CGFloat, screen: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: screen))
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }
        .fill(Color.black.opacity(opacity), style: FillStyle(eoFill: true))
        .contentShape(Rectangle())
        .onTapGesture { viewModel.advance() }
    }

    // MARK: - Tip bubble (Figma 1545:37461)

    private static let bubbleWidth: CGFloat = 306
    private static let arrowSize = CGSize(width: 24, height: 12)

    /// Above the control when it's in the lower half of the screen, below it otherwise; the arrow points at it.
    private func tipBubble(_ tip: CameraTutorialTip, pointingAt control: CGRect, in size: CGSize) -> some View {
        let isAbove = control.midY > size.height / 2
        let left = min(max(control.midX - Self.bubbleWidth / 2, 16), size.width - 16 - Self.bubbleWidth)
        let arrowX = min(max(control.midX - left, 28), Self.bubbleWidth - 28)
        let gap: CGFloat = 4
        return VStack(spacing: 0) {
            if !isAbove { arrow(pointingUp: true, x: arrowX) }
            TipView(tip)
                .tipViewStyle(CameraTutorialTipStyle(onClose: { viewModel.advance() }))
                .frame(width: Self.bubbleWidth)
            if isAbove { arrow(pointingUp: false, x: arrowX) }
        }
        .frame(width: Self.bubbleWidth)
        .offset(x: left)
        .frame(width: size.width,
               height: isAbove ? max(control.minY - gap, 0) : max(size.height - control.maxY - gap, 0),
               alignment: isAbove ? .bottomLeading : .topLeading)
        .frame(width: size.width, height: size.height, alignment: isAbove ? .top : .bottom)
        .allowsHitTesting(true)
        .onTapGesture { viewModel.advance() }
    }

    private func arrow(pointingUp: Bool, x: CGFloat) -> some View {
        TipArrow(pointingUp: pointingUp)
            .fill(DSColor.Paper.normal.color)
            .frame(width: Self.arrowSize.width, height: Self.arrowSize.height)
            .frame(width: Self.bubbleWidth, alignment: .leading)
            .offset(x: x - Self.arrowSize.width / 2)
    }

    // MARK: - Cards and Skip

    private var tryItOutCard: some View {
        StarCard(
            starImage: "StarCharacterHappy",
            starSize: CGSize(width: 85, height: 108),
            messageSize: 17,
            title: "Try it Out",
            message: "Take 2 photos to finish the tutorial.",
            actions: [],
            onDismiss: { viewModel.advance() }
        )
        .simultaneousGesture(TapGesture().onEnded { viewModel.advance() })
    }

    private var finishedCard: some View {
        StarCard(
            starImage: "StarCharacterHappy",
            starSize: CGSize(width: 85, height: 108),
            messageSize: 17,
            title: "Let’s get scrapbooking",
            message: "All shots are used up. Your roll is ready to fill the scrapbook.",
            actions: [StarCard.Action(title: "Open Scrapbook", style: .primary, action: onFinish)]
        )
    }

    /// Figma 1545:37476: a kraft tab on the screen's right edge, top right.
    private var skipTab: some View {
        Button(action: onFinish) {
            Text("Skip")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DSColor.Brand.primary.color)
                .frame(width: 71, height: 34)
                .background(DSColor.Kraft.normal.color,
                            in: UnevenRoundedRectangle(topLeadingRadius: 17, bottomLeadingRadius: 17))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, deviceOrientation.isPortrait ? 56 : 24)
    }
}

/// The screen as the phone is held: content laid out upright in `size`, then turned by `angle` onto the screen.
private struct UserSpace {
    let screen: CGSize
    let angle: Double

    private var isSideways: Bool { Int((abs(angle) / 90).rounded()) % 2 == 1 }

    var size: CGSize { isSideways ? CGSize(width: screen.height, height: screen.width) : screen }

    @ViewBuilder
    func place<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(angle))
            .position(x: screen.width / 2, y: screen.height / 2)
    }

    /// A screen rect in the upright layout.
    func rect(from screenRect: CGRect) -> CGRect {
        let radians = -angle * .pi / 180
        let corners = [
            CGPoint(x: screenRect.minX, y: screenRect.minY), CGPoint(x: screenRect.maxX, y: screenRect.minY),
            CGPoint(x: screenRect.minX, y: screenRect.maxY), CGPoint(x: screenRect.maxX, y: screenRect.maxY),
        ].map { point -> CGPoint in
            let dx = point.x - screen.width / 2, dy = point.y - screen.height / 2
            return CGPoint(x: size.width / 2 + dx * cos(radians) - dy * sin(radians),
                           y: size.height / 2 + dx * sin(radians) + dy * cos(radians))
        }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
}

private struct TipArrow: Shape {
    let pointingUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointingUp {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

/// Figma 1545:37461: paper bubble, bold title with X, body, "tap anywhere to continue".
private struct CameraTutorialTipStyle: TipViewStyle {
    let onClose: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 10) {
                configuration.title
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 26, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next tip")
            }
            configuration.message?
                .font(.system(size: 14))
                .foregroundStyle(DSColor.Brand.primary.color)
                .fixedSize(horizontal: false, vertical: true)
            Text("tap anywhere to continue")
                .font(.system(size: 12).italic())
                .foregroundStyle(DSColor.Component.textSecondary.color)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.Paper.normal.color, in: RoundedRectangle(cornerRadius: 16))
    }
}
