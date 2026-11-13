import SwiftData
import SwiftUI

/// Home Workbench (Figma 853:1703 / 1062:3371 / 1230:20656 portrait, 1563:34278 iPad landscape).
struct WorkbenchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: WorkbenchViewModel
    @State private var toolboxRattle = ToolboxRattleState()
    @State private var rollsBounce = RollClusterBounceState()

    init(modelContext: ModelContext, navigator: any Navigator, sessionStore: SessionStore) {
        _viewModel = State(
            initialValue: WorkbenchViewModel(
                modelContext: modelContext,
                navigator: navigator,
                sessionStore: sessionStore
            )
        )
    }

    init(viewModel: WorkbenchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            workbench
                .ignoresSafeArea()

            // Figma CameraClick "Toolbar - Top", leading button: closes like tapping the blur.
            // Stays inside the safe area (below the status bar / Dynamic Island).
            if viewModel.isCameraActive {
                Button(action: closeCamera) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(DSColor.Brand.primary.color.opacity(0.6))
                }
                .accessibilityLabel("Close")
                .padding(.leading, 16)
                .transition(.opacity)
            }
        }
        .onDisappear {
            viewModel.cancelToolboxTransition()
            viewModel.cancelRollsTransition()
        }
    }

    private var workbench: some View {
        GeometryReader { proxy in
            let layout = WorkbenchLayout(container: proxy.size)
            let isActive = viewModel.isCameraActive
            let isToolboxActive = viewModel.isToolboxActive
            let isRollsActive = viewModel.isRollsActive
            let isBlurred = isActive || isToolboxActive || isRollsActive

            ZStack(alignment: .topLeading) {
                // Desk: every object is placed in the active variant coordinates.
                // Blurs and dims as one flattened sheet when the camera menu, toolbox, or rolls open.
                desk(layout, containerSize: proxy.size)
                    .drawingGroup()
                    // Opaque blur: the screen edges do not fade to the background color.
                    .blur(radius: isBlurred ? 12 : 0, opaque: true)
                    .overlay(Color.black.opacity(isBlurred ? 0.18 : 0))

                // Tap on the blurred desk closes the camera menu.
                if isActive {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { closeCamera() }
                        .zIndex(1)
                }

                rolls(
                    layout,
                    isActive: isRollsActive,
                    isObscured: isActive || isToolboxActive
                )
                .zIndex(isRollsActive ? 3 : 0.25)

                toolbox(
                    layout,
                    isActive: isToolboxActive,
                    isObscured: isActive || isRollsActive
                )
                .zIndex(isToolboxActive ? 3 : 0)

                camera(
                    layout,
                    isActive: isActive,
                    isObscured: isToolboxActive || isRollsActive
                )
                .zIndex((isToolboxActive || isRollsActive) ? 0.5 : 2)

                if isActive {
                    actionButtons(layout)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .zIndex(2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .animation(.spring(response: 0.40, dampingFraction: 0.78), value: isActive)
            .animation(.spring(response: 0.38, dampingFraction: 0.74), value: isToolboxActive)
            .animation(.spring(response: 0.40, dampingFraction: 0.76), value: isRollsActive)
        }
        .background(Color(red: 0.604, green: 0.333, blue: 0.192)) // #9A5531, Figma frame fill behind the desk
    }

    // MARK: - Desk

    @ViewBuilder
    private func desk(_ layout: WorkbenchLayout, containerSize: CGSize) -> some View {
        switch layout.variant {
        case .portrait:
            portraitDesk(layout)
        case .iPadLandscape:
            iPadLandscapeDesk(layout, containerSize: containerSize)
        }
    }

    private func portraitDesk(_ layout: WorkbenchLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(WorkbenchLayout.deskItems, id: \.asset) { item in
                deskImage(item, layout)
                    .position(center(of: item.frame, layout))
                    .allowsHitTesting(false)
            }

            tutorialButton {
                deskImage(WorkbenchLayout.tutorialBook, layout)
            }
            .position(center(of: WorkbenchLayout.tutorialBook.frame, layout))
        }
    }

    private func iPadLandscapeDesk(_ layout: WorkbenchLayout, containerSize: CGSize) -> some View {
        let matFrame = layout.rect(WorkbenchLayout.iPadCuttingMatRect)
        return ZStack(alignment: .topLeading) {
            Image("DeskWoodLandscape")
                .resizable()
                .scaledToFill()
                .frame(width: containerSize.width, height: containerSize.height)
                .clipped()
                .allowsHitTesting(false)

            LandscapeCuttingMatView(scale: layout.scale, size: matFrame.size)
                .position(x: matFrame.midX, y: matFrame.midY)
                .allowsHitTesting(false)

            landscapeImage(WorkbenchLayout.iPadBookBottom, layout)
                .shadow(color: .black.opacity(0.25), radius: layout.length(4), x: 0, y: layout.length(4))
                .allowsHitTesting(false)

            tutorialButton {
                landscapeArtwork(WorkbenchLayout.iPadTutorialBook, layout)
            }
            .rotationEffect(.degrees(WorkbenchLayout.iPadTutorialBook.rotationDegrees))
            .position(layout.point(WorkbenchLayout.iPadTutorialBook.center))
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }

    private func deskImage(_ item: DeskItem, _ layout: WorkbenchLayout) -> some View {
        let frame = layout.rect(item.frame)
        return Image(item.asset)
            .resizable()
            .frame(width: frame.width, height: frame.height)
    }

    private func landscapeArtwork(_ item: LandscapeDeskItem, _ layout: WorkbenchLayout) -> some View {
        let size = layout.size(item.size)
        return Image(item.asset)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
    }

    private func landscapeImage(_ item: LandscapeDeskItem, _ layout: WorkbenchLayout) -> some View {
        landscapeArtwork(item, layout)
            .rotationEffect(.degrees(item.rotationDegrees))
            .position(layout.point(item.center))
    }

    private func tutorialButton<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Button {
            viewModel.openTutorial()
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isCameraActive || viewModel.isToolboxActive || viewModel.isRollsActive)
        .accessibilityLabel("Tutorial Book")
        .accessibilityHint("Tap to open tutorial")
    }

    private func center(of rect: CGRect, _ layout: WorkbenchLayout) -> CGPoint {
        let frame = layout.rect(rect)
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    // MARK: - Film Rolls (Figma 853:1703 / 1563:34278 Idle -> 1235:21168 Centered Active)

    private func rolls(_ layout: WorkbenchLayout, isActive: Bool, isObscured: Bool) -> some View {
        InteractiveRollsView(
            placements: layout.activeRollPlacements,
            layout: layout,
            isActive: isActive,
            isObscured: isObscured,
            isDisabled: viewModel.isCameraActive || viewModel.isToolboxActive || viewModel.cameraReturnPhase != .idle,
            bounce: rollsBounce
        ) {
            HapticService.shared.playSnapFeedback()
            withAnimation(.spring(response: 0.40, dampingFraction: 0.74)) {
                viewModel.activateRolls()
            }
        }
        .task(id: isActive) {
            if isActive {
                await playRollsClusterAnimation()
            } else {
                rollsBounce = RollClusterBounceState()
            }
        }
    }

    @MainActor
    private func playRollsClusterAnimation() async {
        guard !reduceMotion else { return }

        try? await Task.sleep(for: .milliseconds(90))
        if !Task.isCancelled {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.56)) {
                rollsBounce = RollClusterBounceState(scale: 1.07, spread: 1.0, wiggleDegrees: 3.5)
            }
            HapticService.shared.playRatchetTick()
        }

        try? await Task.sleep(for: .milliseconds(160))
        if !Task.isCancelled {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.60)) {
                rollsBounce = RollClusterBounceState(scale: 1.02, spread: 0.4, wiggleDegrees: -2.0)
            }
            HapticService.shared.playRatchetTick()
        }

        try? await Task.sleep(for: .milliseconds(160))
        if !Task.isCancelled {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                rollsBounce = RollClusterBounceState()
            }
        } else {
            rollsBounce = RollClusterBounceState()
        }
    }

    // MARK: - Toolbox (Figma 920:3092 / 1563:34910 Idle -> Centered Active)

    /// Spring-rotates and moves smoothly from its resting corner on the desk to screen center
    /// just like the camera, while the loose tools inside follow with secondary inertia.
    private func toolbox(_ layout: WorkbenchLayout, isActive: Bool, isObscured: Bool) -> some View {
        let activeSize = layout.activeToolboxSize
        let baseSize = layout.size(activeSize)
        let rattleScale = layout.length(activeSize.width / WorkbenchLayout.toolboxSize.width)
        let targetPosition = layout.point(isActive ? layout.activeToolboxActiveCenter : layout.activeToolboxIdleCenter)
        let targetRotation = isActive ? layout.activeToolboxActiveRotation : layout.activeToolboxIdleRotation

        return Button {
            HapticService.shared.playSnapFeedback()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
                viewModel.activateToolbox()
            }
        } label: {
            InteractiveToolboxView(boxSize: baseSize, layoutScale: rattleScale, rattle: toolboxRattle)
                .contentShape(
                    Path(
                        CGRect(
                            x: baseSize.width * 0.15,
                            y: baseSize.height * 0.13,
                            width: baseSize.width * 0.85,
                            height: baseSize.height * 0.80
                        )
                    )
                )
                .scaleEffect(isActive ? layout.activeToolboxActiveScale : 1.0)
                .rotationEffect(.degrees(targetRotation + toolboxRattle.boxDegrees))
                .shadow(
                    color: .black.opacity(isActive ? 0.35 : 0.28),
                    radius: rattleScale * (isActive ? 16 : 4),
                    x: 0,
                    y: rattleScale * (isActive ? 10 : 4)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toolbox")
        .accessibilityHint("Tap to browse your scrapbooks")
        .disabled(viewModel.isCameraActive || viewModel.isRollsActive || viewModel.cameraReturnPhase != .idle)
        .allowsHitTesting(!isActive)
        .blur(radius: isObscured ? 12 : 0)
        .opacity(isObscured ? 0.65 : 1)
        .offset(
            x: rattleScale * toolboxRattle.boxOffset.width,
            y: rattleScale * toolboxRattle.boxOffset.height
        )
        .position(targetPosition)
        .task(id: isActive) {
            if isActive {
                await playToolboxRattle()
            } else {
                toolboxRattle = ToolboxRattleState()
            }
        }
    }

    @MainActor
    private func playToolboxRattle() async {
        guard !reduceMotion else { return }

        // Lead inertia as the toolbox lifts off the desk and sweeps toward center.
        try? await Task.sleep(for: .milliseconds(55))
        if !Task.isCancelled {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.65)) {
                toolboxRattle.toolOffset = CGSize(width: -2.5, height: -2.5)
                toolboxRattle.toolDegrees = -3.5
            }
        }

        let steps: [(delayMs: Int, haptic: Bool, state: ToolboxRattleState)] = [
            (
                125,
                true,
                ToolboxRattleState(
                    boxOffset: CGSize(width: -4.8, height: -2.8),
                    boxDegrees: -3.8,
                    toolOffset: CGSize(width: 3.2, height: 2.2),
                    toolDegrees: 5.0
                )
            ),
            (
                110,
                true,
                ToolboxRattleState(
                    boxOffset: CGSize(width: 5.2, height: 2.4),
                    boxDegrees: 3.8,
                    toolOffset: CGSize(width: -3.4, height: -2.2),
                    toolDegrees: -5.2
                )
            ),
            (
                110,
                true,
                ToolboxRattleState(
                    boxOffset: CGSize(width: -3.4, height: -1.6),
                    boxDegrees: -2.6,
                    toolOffset: CGSize(width: 2.4, height: 1.6),
                    toolDegrees: 3.8
                )
            ),
            (
                110,
                false,
                ToolboxRattleState(
                    boxOffset: CGSize(width: 1.8, height: 0.9),
                    boxDegrees: 1.4,
                    toolOffset: CGSize(width: -1.4, height: -1.0),
                    toolDegrees: -2.2
                )
            ),
        ]

        for step in steps {
            try? await Task.sleep(for: .milliseconds(step.delayMs))
            if Task.isCancelled { break }
            withAnimation(.spring(response: 0.14, dampingFraction: 0.52)) {
                toolboxRattle = step.state
            }
            if step.haptic {
                HapticService.shared.playRatchetTick()
            }
        }

        try? await Task.sleep(for: .milliseconds(105))
        if !Task.isCancelled {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) {
                toolboxRattle = ToolboxRattleState()
            }
        } else {
            toolboxRattle = ToolboxRattleState()
        }
    }

    // MARK: - Camera

    /// Spring-rotates and moves from its spot on the cutting mat to the center (Figma CameraClick).
    /// Hidden during camera return transition while CameraReturnTransitionOverlay animates back to idle (change 086).
    private func camera(_ layout: WorkbenchLayout, isActive: Bool, isObscured: Bool) -> some View {
        let size = layout.activeCameraSize
        let targetPosition = layout.point(isActive ? layout.activeCameraActiveCenter : layout.activeCameraIdleCenter)
        let targetRotation = isActive ? layout.activeCameraActiveRotation : layout.activeCameraIdleRotation

        return Button {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.76)) {
                viewModel.toggleCamera()
            }
        } label: {
            Image("DeskDisposableCamera")
                .resizable()
                .scaledToFit()
                .frame(width: layout.length(size.width), height: layout.length(size.height))
                .rotationEffect(.degrees(targetRotation))
                .shadow(
                    color: .black.opacity(isActive ? 0.35 : 0.22),
                    radius: isActive ? 18 : 8,
                    x: 0,
                    y: isActive ? 10 : 4
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Disposable Camera")
        .accessibilityHint(isActive ? "Camera menu active" : "Tap to open roll menu")
        .disabled(viewModel.isCameraActive || isObscured || viewModel.cameraReturnPhase != .idle)
        .blur(radius: isObscured ? 8 : 0)
        .opacity(viewModel.cameraReturnPhase == .idle ? (isObscured ? 0.45 : 1) : 0)
        .position(targetPosition)
    }

    // MARK: - Create Roll / Join a Roll (unchanged look)

    private func actionButtons(_ layout: WorkbenchLayout) -> some View {
        VStack(spacing: layout.length(16)) {
            actionButton("Create Roll", hint: "Start creating a new film roll", layout: layout) {
                viewModel.startCreateRoll()
            }
            actionButton("Join a Roll", hint: "Join an existing roll using a code or link", layout: layout) {
                viewModel.startJoinRoll()
            }
        }
        .position(layout.point(layout.activeActionButtonsCenter))
    }

    private func actionButton(_ title: String, hint: String, layout: WorkbenchLayout, action: @escaping () -> Void) -> some View {
        let size = layout.activeActionButtonSize
        let ink = Color(red: 0.16, green: 0.14, blue: 0.12) // #2A241F
        return Button(action: action) {
            Text(title)
                .font(.system(size: layout.length(20), weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
                .frame(width: layout.length(size.width), height: layout.length(size.height))
                .background(
                    ZStack {
                        Capsule()
                            .fill(ink)
                            .offset(y: layout.length(7))
                        Capsule()
                            .fill(Color(red: 0.996, green: 0.996, blue: 0.992)) // #FEFEFD
                            .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                    }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }

    private func closeCamera() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
            viewModel.dismissCamera()
        }
    }
}

/// Vector-drawn `1210×652` landscape cutting mat (Figma `1563:34284` + `1563:34337`) with 1–27 grid and rulers.
private struct LandscapeCuttingMatView: View {
    let scale: CGFloat
    let size: CGSize

    private static let matLight = Color(red: 45 / 255, green: 119 / 255, blue: 87 / 255)   // #2D7757
    private static let matMid = Color(red: 45 / 255, green: 119 / 255, blue: 88 / 255)     // #2D7758
    private static let matEdge = Color(red: 32 / 255, green: 110 / 255, blue: 80 / 255)    // #206E50
    private static let inkPaper = Color(red: 254 / 255, green: 254 / 255, blue: 253 / 255) // #FEFEFD
    private static let matShadow = Color(red: 13 / 255, green: 26 / 255, blue: 15 / 255)

    private static let verticalXs: [CGFloat] = (0...25).map { CGFloat(18 + $0 * 44) } + [1156, 1200]
    private static let horizontalYs: [CGFloat] = [68, 112, 156, 200, 244, 288, 332, 376, 419, 463, 507, 551, 595]

    var body: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(
                stops: [
                    .init(color: Self.matLight, location: 0.0),
                    .init(color: Self.matMid, location: 0.58),
                    .init(color: Self.matEdge, location: 1.0),
                ],
                center: UnitPoint(x: 0.494, y: 0.495),
                startRadius: 0,
                endRadius: 680 * scale
            )

            softTextureOverlay

            Canvas { context, _ in
                drawGrid(in: &context)
                drawTicks(in: &context)
            }

            rulerNumbers

            // Subtle inner shadow along the top and bottom wood seams (Figma rgba(13,26,15,0.32)).
            VStack(spacing: 0) {
                LinearGradient(colors: [Self.matShadow.opacity(0.32), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 10 * scale)
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, Self.matShadow.opacity(0.22)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 8 * scale)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var softTextureOverlay: some View {
        ZStack(alignment: .topLeading) {
            softEllipse(cx: 100, cy: 140, width: 160, height: 180, color: Color(red: 0.80, green: 0.92, blue: 0.72), opacity: 0.10)
            softEllipse(cx: 410, cy: 100, width: 190, height: 160, color: Color(red: 0.06, green: 0.16, blue: 0.08), opacity: 0.12)
            softEllipse(cx: 270, cy: 310, width: 220, height: 160, color: Color(red: 0.80, green: 0.92, blue: 0.74), opacity: 0.08)
            softEllipse(cx: 475, cy: 370, width: 190, height: 180, color: Color(red: 0.06, green: 0.15, blue: 0.08), opacity: 0.10)
        }
        .opacity(0.25)
    }

    private func softEllipse(cx: CGFloat, cy: CGFloat, width: CGFloat, height: CGFloat, color: Color, opacity: Double) -> some View {
        Ellipse()
            .fill(color.opacity(opacity))
            .frame(width: width * scale, height: height * scale)
            .blur(radius: 14 * scale)
            .position(x: cx * scale, y: cy * scale)
    }

    private func drawGrid(in context: inout GraphicsContext) {
        let color = Self.inkPaper.opacity(0.45)
        let line = max(1 * scale, 1)
        for x in Self.verticalXs {
            context.fill(
                Path(CGRect(x: x * scale, y: 30 * scale, width: line, height: 590 * scale)),
                with: .color(color)
            )
        }
        for y in Self.horizontalYs {
            context.fill(
                Path(CGRect(x: 18 * scale, y: y * scale, width: 1182 * scale, height: line)),
                with: .color(color)
            )
        }
    }

    private func drawTicks(in context: inout GraphicsContext) {
        let color = Self.inkPaper.opacity(0.72)
        let line = max(1 * scale, 1)

        var topX: CGFloat = 5
        while topX <= 1204 {
            let isMajor = Int(topX - 27).isMultiple(of: 44)
            let height: CGFloat = isMajor ? 9 : 5
            context.fill(
                Path(CGRect(x: topX * scale, y: 1 * scale, width: line, height: height * scale)),
                with: .color(color)
            )
            topX += 11
        }

        var bottomX: CGFloat = 12
        while bottomX <= 1200 {
            let isMajor = Int(bottomX - 23).isMultiple(of: 44)
            let height: CGFloat = isMajor ? 5 : 3
            let topY: CGFloat = isMajor ? 647 : 649
            context.fill(
                Path(CGRect(x: bottomX * scale, y: topY * scale, width: line, height: height * scale)),
                with: .color(color)
            )
            bottomX += 11
        }
    }

    private var rulerNumbers: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<27, id: \.self) { index in
                Text("\(index + 1)")
                    .font(.system(size: 15 * scale))
                    .foregroundStyle(Self.inkPaper.opacity(0.9))
                    .position(x: CGFloat(23 + index * 44) * scale, y: 638 * scale)

                Text("\(27 - index)")
                    .font(.system(size: 15 * scale))
                    .foregroundStyle(Self.inkPaper.opacity(0.9))
                    .rotationEffect(.degrees(180))
                    .position(x: CGFloat(27 + index * 44) * scale, y: 19 * scale)
            }
        }
    }
}
