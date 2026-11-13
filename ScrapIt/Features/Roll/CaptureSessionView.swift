import SwiftUI

struct CaptureSessionView: View {
    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    @State private var simulatedLandscapeSide: RollCameraOrientation.LandscapeSide = .left
    @State private var deviceOrientation: RollCameraOrientation.DeviceOrientation = .landscapeLeft
    @State private var zoomTextRotation: Double = 0.0
    @State private var motionService = CameraMotionService()
    @State private var isClosingIrisOnReturn: Bool = false
    @State private var popup1Opacity: Double = 1.0
    @State private var popup2Opacity: Double = 1.0
    @State private var isTransitioningBetweenPopups: Bool = false
    private var isAnyPopupPresented: Bool {
        flowViewModel.showEndRollConfirmation || flowViewModel.showRollCompletePopup
    }

    private var camera: CameraController {
        flowViewModel.camera
    }

    private var isHost: Bool {
        flowViewModel.isHost(currentUser)
    }

    private var currentInterfaceOrientation: UIInterfaceOrientation {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) {
            return activeScene.interfaceOrientation
        }
        return scenes.first?.interfaceOrientation ?? .unknown
    }

    private var symbolRotation: Double {
        RollCameraOrientation.symbolRotationDegrees(for: deviceOrientation)
    }

    private var isPortraitOrientation: Bool {
        deviceOrientation.isPortrait
    }

    private var liveBadgeCenter: CGPoint {
        if isPortraitOrientation {
            // Visual width becomes 20.21, visual height becomes 44.57 -> 10pt top & leading margin
            return CGPoint(x: 10 + 20.21 / 2, y: 10 + 44.57 / 2)
        } else {
            // Visual width is 44.57, visual height is 20.21 -> 10pt top & leading margin
            return CGPoint(x: 10 + 44.57 / 2, y: 10 + 20.21 / 2)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width
            let windowOrientation = currentInterfaceOrientation
            let rotationDegrees = RollCameraOrientation.viewRotationDegrees(
                isPortraitWindow: isPortrait,
                windowInterfaceOrientation: windowOrientation,
                physicalSide: simulatedLandscapeSide
            )

            // Figma design native canvas: 874 x 402 pt (matches iPhone Pro landscape dimensions)
            let canvasWidth: CGFloat = 874
            let canvasHeight: CGFloat = 402

            // Viewport dimensions filling entire screen edge-to-edge
            let viewportWidth = isPortrait ? geo.size.height : geo.size.width
            let viewportHeight = isPortrait ? geo.size.width : geo.size.height

            // Scale factor to ensure everything is completely flush with screen edges
            let scale = max(viewportWidth / canvasWidth, viewportHeight / canvasHeight)

            ZStack {
                Color(red: 42 / 255, green: 36 / 255, blue: 31 / 255)
                    .ignoresSafeArea()

                cameraCanvas
                    .frame(width: canvasWidth, height: canvasHeight)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotationDegrees))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                if isAnyPopupPresented {
                    popupOverlay(isPortraitWindow: isPortrait)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isAnyPopupPresented)
            .ignoresSafeArea()
            .onChange(of: isPortrait) { _, newIsPortrait in
                camera.setSimulatedLandscapeSide(
                    simulatedLandscapeSide,
                    isPortrait: newIsPortrait,
                    windowOrientation: windowOrientation,
                    deviceOrientation: deviceOrientation
                )
            }
            .onChange(of: simulatedLandscapeSide) { _, newSide in
                camera.setSimulatedLandscapeSide(
                    newSide,
                    isPortrait: isPortrait,
                    windowOrientation: windowOrientation,
                    deviceOrientation: deviceOrientation
                )
            }
            .onChange(of: deviceOrientation) { _, newOrientation in
                camera.setSimulatedLandscapeSide(
                    simulatedLandscapeSide,
                    isPortrait: isPortrait,
                    windowOrientation: windowOrientation,
                    deviceOrientation: newOrientation
                )
            }
            .onAppear {
                zoomTextRotation = RollCameraOrientation.zoomTextRotationDegrees(
                    for: deviceOrientation,
                    previousRotation: zoomTextRotation
                )
                motionService.start { newOrientation in
                    guard newOrientation != deviceOrientation else { return }
                    deviceOrientation = newOrientation
                    if let side = newOrientation.landscapeSide, side != simulatedLandscapeSide {
                        simulatedLandscapeSide = side
                    }
                    zoomTextRotation = RollCameraOrientation.zoomTextRotationDegrees(
                        for: newOrientation,
                        previousRotation: zoomTextRotation
                    )
                }
                camera.setSimulatedLandscapeSide(
                    simulatedLandscapeSide,
                    isPortrait: isPortrait,
                    windowOrientation: windowOrientation,
                    deviceOrientation: deviceOrientation
                )
                OrientationLock.set(.portrait)
                flowViewModel.cameraDidAppear()
            }
            .onDisappear {
                motionService.stop()
                camera.setSimulatedLandscapeSide(
                    .left,
                    isPortrait: false,
                    windowOrientation: .unknown,
                    deviceOrientation: .landscapeLeft
                )
                OrientationLock.resetToPortrait()
                flowViewModel.cameraDidDisappear()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(flowViewModel.cameraReturnPhase == .idle && !isClosingIrisOnReturn)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden()
        .background(
            // Only on while the session runs: enabled earlier, iOS routes Camera Control to the system Camera app.
            CaptureEventView(
                isEnabled: camera.isSessionRunning,
                onPrimary: {
                    flowViewModel.primaryButtonPressed(currentUser: currentUser)
                },
                onSecondary: {
                    camera.handleSecondaryButton()
                }
            )
        )
        .alert("Turn On Camera Adjustments", isPresented: Bindable(camera).showsCameraAdjustmentsPrompt) {
            Button("Already On") { camera.confirmCameraAdjustmentsOn() }
            Button("Don't Remind Me") { camera.dismissCameraAdjustmentsPromptForever() }
            Button("Later", role: .cancel) {}
        } message: {
            Text("To zoom and switch cameras with a light press on Camera Control, turn on Camera Adjustments in Settings › Camera › Camera Control.")
        }
        .sheet(isPresented: $flowViewModel.isInviteSheetPresented) {
            InviteFriendSheetView(currentUser: currentUser, flowViewModel: flowViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Roll Finished", isPresented: $flowViewModel.showLastSlotRaceAlert) {
            Button("Open Scrapbook") {
                OrientationLock.resetToPortrait()
                flowViewModel.finalizeSessionAndOpenScrapbook()
            }
        } message: {
            Text(flowViewModel.lastSlotRaceMessage)
        }
    }

    // MARK: - Camera Canvas (874 x 402 Figma Frame 1458:26041)

    private var cameraCanvas: some View {
        ZStack(alignment: .topLeading) {
            // 1. Textured Camera Body Shape from Figma
            Image("CameraBodyShape")
                .resizable()
                .frame(width: 874, height: 402)
                .position(x: 874 / 2, y: 402 / 2)

            // 2. Left Column: Upper Flash Button Well (Figma Group 73: left 62, top 33, 60x120)
            flashButtonView
                .frame(width: 60, height: 120)
                .position(x: 62 + 60 / 2, y: 33 + 120 / 2)

            // 3. Left Column: Lower Back Navigation Button (aligned flush to bottom of viewfinder margin at y: 370)
            backButtonView
                .frame(width: 60, height: 60)
                .position(x: 62 + 60 / 2, y: 310 + 60 / 2)

            // 4. Center: Viewfinder Screen Bezel & Live Preview (Figma Group 67: left 136, top 33, 444.4x337)
            screenBezelView
                .frame(width: 444.406, height: 337)
                .position(x: 136 + 444.406 / 2, y: 33 + 337 / 2)

            // 5. Right Area: Zoom Control (Figma 1477:26750: left 594, top 14, 172x83)
            zoomControlView
                .frame(width: 172, height: 83)
                .position(x: 594 + 172 / 2, y: 14 + 83 / 2)

            // 6. Right Area: Dedicated Host End Roll Button (aligned with middle of zoom wheel at y: 63)
            if isHost {
                endRollButton
                    .frame(width: 36, height: 48)
                    .position(x: 874 - 36 / 2, y: 63)
            }

            // 7. Right Area: Recessed Shutter Well & Button (Figma Group 68: left 594, top 128, 154x154)
            shutterWellView
                .frame(width: 154, height: 154)
                .position(x: 594 + 154 / 2, y: 128 + 154 / 2)

            // 8. Right Area: Flip Camera Button (Figma Group 74: left 596, top 298, 72x72)
            flipButtonView
                .frame(width: 72, height: 72)
                .position(x: 596 + 72 / 2, y: 298 + 72 / 2)

            // 9. Right Area: Circular Analog Shots-Left Dial (Figma 1458:26072: left 763, top 287, 83x83)
            ShotsLeftDialView(
                shotsRemaining: flowViewModel.shotsRemaining,
                totalShots: flowViewModel.activeSession?.rollSize ?? 36,
                isSyncing: flowViewModel.isSyncingShot
            )
            .rotationEffect(.degrees(symbolRotation))
            .animation(.easeInOut(duration: 0.3), value: symbolRotation)
            .frame(width: 83, height: 83)
            .position(x: 763 + 83 / 2, y: 287 + 83 / 2)
        }
        .frame(width: 874, height: 402)
        .clipped()
    }

    // MARK: - Flash Button Well (Figma Group 73: ON node 1458:26095, OFF node 1476:26501)

    private var flashButtonView: some View {
        Button {
            HapticService.shared.playSnapFeedback()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                camera.cycleFlash()
            }
        } label: {
            ZStack {
                let isFlashOn = camera.flashChoice == .on

                // Outer Recessed Well (60 x 120, rounded 20)
                // When ON: green gradient (#40663d to #40653d)
                // When OFF: dark grey gradient (#474747 to #454545, node 1476:26501)
                RoundedRectangle(cornerRadius: 20)
                    .withInnerShadow(
                        fill: LinearGradient(
                            stops: isFlashOn ? [
                                .init(color: Color(red: 64 / 255, green: 102 / 255, blue: 61 / 255), location: 0.0),
                                .init(color: Color(red: 69 / 255, green: 102 / 255, blue: 66 / 255), location: 0.6438),
                                .init(color: Color(red: 64 / 255, green: 101 / 255, blue: 61 / 255), location: 1.0)
                            ] : [
                                .init(color: Color(red: 71 / 255, green: 71 / 255, blue: 71 / 255), location: 0.0),
                                .init(color: Color(red: 67 / 255, green: 64 / 255, blue: 64 / 255), location: 0.6438),
                                .init(color: Color(red: 69 / 255, green: 69 / 255, blue: 69 / 255), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        shadowColor: Color.black.opacity(0.8),
                        radius: 3.7,
                        x: 0,
                        y: 4.5
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)

                // Flash SF Symbol:
                // When ON: bolt.fill in bottom position (y = 89)
                // When OFF: bolt.slash.fill in top position (y = 31)
                if isFlashOn {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(Color(red: 252 / 255, green: 251 / 255, blue: 248 / 255))
                        .rotationEffect(.degrees(symbolRotation))
                        .animation(.easeInOut(duration: 0.3), value: symbolRotation)
                        .position(x: 30, y: 89)
                        .transition(.opacity)
                } else {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 23, weight: .regular))
                        .foregroundStyle(Color(red: 200 / 255, green: 198 / 255, blue: 192 / 255))
                        .rotationEffect(.degrees(symbolRotation))
                        .animation(.easeInOut(duration: 0.3), value: symbolRotation)
                        .position(x: 30, y: 31)
                        .transition(.opacity)
                }

                // Physical Sliding Switch Thumb (44 x 44 rounded square, rounded 13)
                // Inset by 8pt from edges: width 44 inside 60 leaves 8pt on left & right.
                // When ON: at top (y: 30). When OFF: at bottom (y: 90). Both 8pt from ends.
                RoundedRectangle(cornerRadius: 13)
                    .withInnerShadow(
                        fill: RadialGradient(
                            stops: [
                                .init(color: Color(red: 203 / 255, green: 203 / 255, blue: 203 / 255), location: 0.0),
                                .init(color: Color(red: 160 / 255, green: 160 / 255, blue: 160 / 255), location: 1.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 24
                        ),
                        shadowColor: Color.black.opacity(0.25),
                        radius: 5.0,
                        x: 0,
                        y: 2.0
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 2)
                    .frame(width: 44, height: 44)
                    .position(
                        x: 30,
                        y: isFlashOn ? 30 : 90
                    )
            }
            .frame(width: 60, height: 120)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(camera.flashChoice == .on ? "Flash On" : "Flash Off")
    }

    // MARK: - Back Navigation Button (Figma Group 71: node 1458:26114)

    private var backButtonView: some View {
        Button {
            guard flowViewModel.cameraReturnPhase == .idle, !isClosingIrisOnReturn else { return }
            isClosingIrisOnReturn = true
            HapticService.shared.playSnapFeedback()
            let returnAngle = RollCameraOrientation.cameraReturnAngle(
                deviceOrientation: deviceOrientation,
                fallbackSide: simulatedLandscapeSide
            )
            Task { @MainActor in
                // Allow mechanical iris closure (~180ms) before initiating return resize and flip
                try? await Task.sleep(nanoseconds: 180_000_000)
                flowViewModel.prepareCameraReturn(angle: returnAngle)
            }
        } label: {
            ZStack {
                Circle()
                    .withInnerShadow(
                        fill: RadialGradient(
                            stops: [
                                .init(color: Color(red: 88 / 255, green: 88 / 255, blue: 88 / 255), location: 0.0),
                                .init(color: Color(red: 66 / 255, green: 66 / 255, blue: 66 / 255), location: 0.5),
                                .init(color: Color(red: 44 / 255, green: 44 / 255, blue: 44 / 255), location: 1.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        ),
                        shadowColor: Color.black.opacity(0.35),
                        radius: 5.0,
                        x: 0,
                        y: 2.0
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)

                Image(systemName: "chevron.backward")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 228 / 255, green: 228 / 255, blue: 228 / 255))
                    .rotationEffect(.degrees(symbolRotation))
                    .animation(.easeInOut(duration: 0.3), value: symbolRotation)
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
        .disabled(flowViewModel.cameraReturnPhase != .idle || isClosingIrisOnReturn)
        .accessibilityLabel("Return to Homepage")
    }

    // MARK: - Viewfinder Screen Bezel & Live Preview (Figma Group 67)

    private var screenBezelView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14.5)
                .fill(Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255))
                .overlay(
                    RoundedRectangle(cornerRadius: 14.5)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 5.2, x: 0, y: 5.2)

            // Live Preview with Roll Filter (424 x 318, 4:3)
            ZStack {
                Color(red: 28 / 255, green: 27 / 255, blue: 26 / 255)

                if let renderer = camera.previewRenderer {
                    FilteredCameraPreviewView(renderer: renderer)
                }

                // Shutter flash feedback
                RoundedRectangle(cornerRadius: 6.2)
                    .fill(Color.white.opacity(camera.shutterFlashOpacity))
                    .animation(.easeOut(duration: 0.1), value: camera.shutterFlashOpacity)
                    .allowsHitTesting(false)

                // Viewfinder HUD: LIVE badge button & Host Handover banner
                viewfinderHUD

                // Mechanical Iris Diaphragm Overlay (aperture blades constricting on camera switch or return home)
                CameraIrisDiaphragmView(isClosed: camera.isSwitchingCamera || isClosingIrisOnReturn)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6.2))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 444.406, height: 337)
    }

    private var viewfinderHUD: some View {
        ZStack(alignment: .topLeading) {
            // Interactive LIVE indicator button replacing participants badge
            liveBadgeButton
                .position(liveBadgeCenter)
                .animation(.easeInOut(duration: 0.3), value: isPortraitOrientation)

            // Host Handover Banner (Centered)
            if let banner = flowViewModel.hostHandoverBanner {
                Text(banner)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ScrapTheme.cameraGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .position(x: 424 / 2, y: 318 / 2)
            }
        }
        .frame(width: 424, height: 318)
    }

    private var liveBadgeButton: some View {
        Button {
            camera.isLivePhotoEnabled.toggle()
        } label: {
            Text("LIVE")
                .font(.system(size: 11.4, weight: .semibold))
                .tracking(0.91)
                .foregroundStyle(Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255))
                .padding(.horizontal, 8.3)
                .padding(.vertical, 3.1)
                .overlay {
                    if !camera.isLivePhotoEnabled {
                        DiagonalSlashShape()
                            .stroke(
                                Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255),
                                style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 4.14)
                        .fill(Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255).opacity(0.62))
                )
        }
        .buttonStyle(.plain)
        .rotationEffect(.degrees(symbolRotation))
        .animation(.easeInOut(duration: 0.3), value: symbolRotation)
        .accessibilityLabel(camera.isLivePhotoEnabled ? "Live Photo Enabled" : "Live Photo Disabled")
    }

    // MARK: - Zoom Control (Figma 1477:26750)
    // Container at (594 + 172/2, 14 + 83/2) = (680, 55.5), y spans 14...97
    // Wheel top is at y = 14 + 19 = 33, exactly flush with Viewfinder bezel top (y = 33)

    private var zoomControlView: some View {
        ZStack {
            Text(String(format: "ZOOM %.1f×", camera.zoomFactor))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.88)
                .foregroundStyle(Color(red: 185 / 255, green: 181 / 255, blue: 173 / 255))
                .modifier(ZoomTextVerticalFlipModifier(angle: zoomTextRotation))
                .animation(.easeInOut(duration: 0.35), value: zoomTextRotation)
                .position(x: 86, y: 7)

            KnurledZoomWheelView(
                capabilities: camera.zoomCapabilities,
                zoomFactor: camera.zoomFactor,
                isEnabled: !camera.isUsingFrontCamera,
                onZoomChanged: { camera.setZoomFactor($0) }
            )
            .frame(width: 160, height: 60)
            .position(x: 86, y: 49)
        }
        .frame(width: 172, height: 83)
    }

    // MARK: - Dedicated Host End Roll Button (Figma Group 72: low profile)

    private var endRollButton: some View {
        Button {
            HapticService.shared.playSnapFeedback()
            flowViewModel.presentEndRollConfirmation()
        } label: {
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: 14,
                    bottomLeadingRadius: 14,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .withInnerShadow(
                    fill: RadialGradient(
                        stops: [
                            .init(color: Color(red: 160 / 255, green: 70 / 255, blue: 70 / 255), location: 0.45),
                            .init(color: Color(red: 124 / 255, green: 53 / 255, blue: 53 / 255), location: 1.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 28
                    ),
                    shadowColor: Color.black.opacity(0.35),
                    radius: 3.0,
                    x: -1,
                    y: 1
                )
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: -1, y: 1)
                .frame(width: 36, height: 48)

                Text("End Roll")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(-0.43)
                    .foregroundStyle(Color(red: 254 / 255, green: 253 / 255, blue: 251 / 255))
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 36, height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("End Roll")
    }

    // MARK: - Shutter Well & Button (Figma Group 68: node 1458:26069)

    private var shutterWellView: some View {
        Button {
            Task {
                await flowViewModel.shutterTapped(currentUser: currentUser)
            }
        } label: {
            EmptyView()
        }
        .buttonStyle(ShutterButtonStyle(isProgrammaticallyPressed: flowViewModel.isShutterPressed))
        .accessibilityLabel("Shutter")
    }

    // MARK: - Flip Camera Button (Figma Group 74: node 1458:26103)

    private var flipButtonView: some View {
        Button {
            HapticService.shared.playSnapFeedback()
            camera.toggleCameraPosition()
        } label: {
            ZStack {
                // Outer Recessed Green Well (72 x 72)
                Circle()
                    .withInnerShadow(
                        fill: LinearGradient(
                            stops: [
                                .init(color: Color(red: 46 / 255, green: 73 / 255, blue: 44 / 255), location: 0.0),
                                .init(color: Color(red: 71 / 255, green: 112 / 255, blue: 67 / 255), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        shadowColor: Color.black.opacity(0.8),
                        radius: 3.7,
                        x: 0,
                        y: 4.5
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)

                // Silver Convex Button (58 x 58)
                Circle()
                    .withInnerShadow(
                        fill: RadialGradient(
                            stops: [
                                .init(color: Color(red: 182 / 255, green: 182 / 255, blue: 182 / 255), location: 0.0),
                                .init(color: Color(red: 153 / 255, green: 153 / 255, blue: 153 / 255), location: 0.55),
                                .init(color: Color(red: 122 / 255, green: 122 / 255, blue: 122 / 255), location: 1.0)
                            ],
                            center: UnitPoint(x: 0.4, y: 0.35),
                            startRadius: 0,
                            endRadius: 29
                        ),
                        shadowColor: Color.black.opacity(0.22),
                        radius: 3.7,
                        x: 0,
                        y: -4.5
                    )
                    .shadow(color: Color.black.opacity(0.55), radius: 4.5, x: 0, y: 5.9)
                    .frame(width: 58, height: 58)

                // Rotating Switch Symbol
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(Color(red: 252 / 255, green: 251 / 255, blue: 248 / 255))
                    .rotationEffect(.degrees(symbolRotation))
                    .animation(.easeInOut(duration: 0.3), value: symbolRotation)
                    .opacity(camera.isSwitchingCamera ? 0.6 : 1.0)
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(.plain)
        .disabled(camera.isSwitchingCamera)
        .accessibilityLabel("Flip Camera")
    }

    // MARK: - End Roll & Roll Complete Popups (Figma 1517:25254 & 1512:26505)

    @ViewBuilder
    private func popupOverlay(isPortraitWindow: Bool) -> some View {
        let rotationAngle: Double = {
            if isPortraitWindow {
                return RollCameraOrientation.cameraReturnAngle(deviceOrientation: deviceOrientation)
            } else {
                return RollCameraOrientation.symbolRotationDegrees(for: deviceOrientation)
            }
        }()

        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !isTransitioningBetweenPopups else { return }
                    if flowViewModel.showEndRollConfirmation {
                        flowViewModel.dismissEndRollConfirmation()
                    }
                }

            if flowViewModel.showEndRollConfirmation {
                EndRollConfirmationPopupView(
                    shotsRemaining: flowViewModel.shotsRemaining,
                    onCancel: {
                        guard !isTransitioningBetweenPopups else { return }
                        flowViewModel.dismissEndRollConfirmation()
                    },
                    onConfirm: {
                        guard !isTransitioningBetweenPopups else { return }
                        isTransitioningBetweenPopups = true
                        // Step 1: Fade out popup 1 completely first
                        withAnimation(.easeInOut(duration: 0.2)) {
                            popup1Opacity = 0.0
                        }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            // Step 2: Swap to popup 2 invisibly while at 0 opacity
                            popup2Opacity = 0.0
                            flowViewModel.confirmEndRollByHost(currentUser: currentUser)
                            popup1Opacity = 1.0
                            // Step 3: Hold 250ms pause between popups
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            // Step 4: Fade in popup 2
                            withAnimation(.easeInOut(duration: 0.2)) {
                                popup2Opacity = 1.0
                            }
                            isTransitioningBetweenPopups = false
                        }
                    }
                )
                .opacity(popup1Opacity)
                .rotationEffect(.degrees(rotationAngle))
                .animation(.easeInOut(duration: 0.3), value: deviceOrientation)
            } else if flowViewModel.showRollCompletePopup {
                RollCompletePopupView(
                    isEndedEarly: flowViewModel.isRollEndedEarly,
                    onReveal: {
                        flowViewModel.transitionToRollReveal()
                    }
                )
                .opacity(popup2Opacity)
                .rotationEffect(.degrees(rotationAngle))
                .animation(.easeInOut(duration: 0.3), value: deviceOrientation)
            }
        }
        .zIndex(100)
    }
}

private struct ShutterButtonStyle: ButtonStyle {
    let isProgrammaticallyPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed || isProgrammaticallyPressed
        ZStack {
            // Outer Recessed Green Well (154 x 154) - remains stationary
            Circle()
                .withInnerShadow(
                    fill: LinearGradient(
                        stops: [
                            .init(color: Color(red: 46 / 255, green: 73 / 255, blue: 44 / 255), location: 0.0),
                            .init(color: Color(red: 71 / 255, green: 112 / 255, blue: 67 / 255), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    shadowColor: Color.black.opacity(0.8),
                    radius: 3.7,
                    x: 0,
                    y: 4.5
                )
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)

            // 3D Spherical Metallic Shutter Button Dome (130 x 130) - ONLY this depresses on tap
            Circle()
                .withInnerShadow(
                    fill: RadialGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: Color(red: 200 / 255, green: 200 / 255, blue: 200 / 255), location: 0.4),
                            .init(color: Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255), location: 0.75),
                            .init(color: Color(red: 114 / 255, green: 114 / 255, blue: 114 / 255), location: 1.0)
                        ],
                        center: UnitPoint(x: 0.45, y: 0.4),
                        startRadius: 0,
                        endRadius: 65
                    ),
                    shadowColor: Color.black.opacity(0.22),
                    radius: 3.7,
                    x: 0,
                    y: -4.5
                )
                .shadow(color: Color.black.opacity(0.55), radius: 4.5, x: 0, y: 5.9)
                .frame(width: 130, height: 130)
                .scaleEffect(isPressed ? 0.94 : 1.0)
                .opacity(isPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.18, dampingFraction: 0.65), value: isPressed)
        }
        .frame(width: 154, height: 154)
        .contentShape(Circle())
    }
}

// MARK: - Shape Inner Shadow Helper

private struct DiagonalSlashShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 4.5, y: rect.height - 4.5))
        path.addLine(to: CGPoint(x: rect.width - 4.5, y: 4.5))
        return path
    }
}

private extension Shape {
    func withInnerShadow<S: ShapeStyle>(
        fill: S,
        shadowColor: Color = Color.black.opacity(0.8),
        radius: CGFloat = 3.7,
        x: CGFloat = 0,
        y: CGFloat = 4.5
    ) -> some View {
        self.fill(fill)
            .overlay(
                self
                    .stroke(shadowColor, lineWidth: radius * 2)
                    .offset(x: x, y: y)
                    .blur(radius: radius)
                    .mask(self)
            )
    }
}

// MARK: - Zoom Text Vertical 3D Flip Modifier

private struct ZoomTextVerticalFlipModifier: AnimatableModifier {
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let isFlipped = angle > 90.0
        content
            .scaleEffect(x: isFlipped ? -1.0 : 1.0, y: 1.0)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                perspective: 0.6
            )
    }
}


