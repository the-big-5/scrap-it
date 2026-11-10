import SwiftUI

struct CaptureSessionView: View {
    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    #if DEBUG
    @State private var showsDebugLastShot = false
    #endif
    @State private var simulatedLandscapeSide: RollCameraOrientation.LandscapeSide = .left
    @State private var motionService = CameraMotionService()

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
            }
            .ignoresSafeArea()
            .onChange(of: isPortrait) { _, newIsPortrait in
                camera.setSimulatedLandscapeSide(simulatedLandscapeSide, isPortrait: newIsPortrait, windowOrientation: windowOrientation)
            }
            .onChange(of: simulatedLandscapeSide) { _, newSide in
                camera.setSimulatedLandscapeSide(newSide, isPortrait: isPortrait, windowOrientation: windowOrientation)
            }
            .onAppear {
                motionService.start { newSide in
                    if newSide != simulatedLandscapeSide {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            simulatedLandscapeSide = newSide
                        }
                    }
                }
                camera.setSimulatedLandscapeSide(simulatedLandscapeSide, isPortrait: isPortrait, windowOrientation: windowOrientation)
                OrientationLock.set(OrientationLock.mask(isCaptureSessionVisible: true))
                flowViewModel.cameraDidAppear()
            }
            .onDisappear {
                motionService.stop()
                camera.setSimulatedLandscapeSide(.left, isPortrait: false, windowOrientation: .unknown)
                OrientationLock.set(OrientationLock.mask(isCaptureSessionVisible: false))
                flowViewModel.cameraDidDisappear()
            }
        }
        .ignoresSafeArea()
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
        #if DEBUG
        .sheet(isPresented: $showsDebugLastShot) {
            DebugLastShotView(photo: flowViewModel.debugLastShot)
        }
        #endif
        .sheet(isPresented: $flowViewModel.isInviteSheetPresented) {
            InviteFriendSheetView(currentUser: currentUser, flowViewModel: flowViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Roll Finished", isPresented: $flowViewModel.showLastSlotRaceAlert) {
            Button("Open Scrapbook") {
                flowViewModel.finalizeSessionAndOpenScrapbook()
            }
        } message: {
            Text(flowViewModel.lastSlotRaceMessage)
        }
    }

    // MARK: - Camera Canvas (874 x 402 Figma Frame)

    /// Leading margin offset for viewfinder and controls to clear the Dynamic Island in landscape.
    private let viewfinderLeadingOffset: CGFloat = 64

    private var cameraCanvas: some View {
        ZStack(alignment: .topLeading) {
            // 1. Textured Camera Body Shape from Figma (1302:47937)
            Image("CameraBodyShape")
                .resizable()
                .frame(width: 874, height: 402)
                .position(x: 874 / 2, y: 402 / 2)

            // 2. Screen Bezel & Live Preview (1302:47969)
            screenBezelView
                .frame(width: 487, height: 251)
                .position(x: viewfinderLeadingOffset + 487 / 2, y: 97 + 251 / 2)

            // 3. Bottom Controls Row (Flash, Live, Flip) with Equal Spacing
            bottomControlsRow
                .frame(width: 487, height: 32)
                .position(x: viewfinderLeadingOffset + 487 / 2, y: 380)

            // 4. Shutter Well & Button (1302:47961)
            shutterWellView
                .frame(width: 107, height: 107)
                .position(x: 567 + 107 / 2, y: 164 + 107 / 2)

            // 5. Circular Analog Shots-Left Dial (1302:47951)
            ShotsLeftDialView(
                shotsRemaining: flowViewModel.shotsRemaining,
                totalShots: flowViewModel.activeSession?.rollSize ?? 36
            )
                .frame(width: 83, height: 83)
                .position(x: 697 + 83 / 2, y: 271 + 83 / 2)

            // 6. Top Plate (1302:47984)
            topPlateView
                .frame(width: 875, height: 83)
                .position(x: 875 / 2, y: 83 / 2)
        }
        .frame(width: 874, height: 402)
        .clipped()
    }

    // MARK: - Top Plate

    private var topPlateView: some View {
        ZStack(alignment: .topLeading) {
            // Metallic Gradient Background
            LinearGradient(
                stops: [
                    .init(color: Color(red: 42 / 255, green: 36 / 255, blue: 31 / 255), location: 0.0),
                    .init(color: Color(red: 23 / 255, green: 23 / 255, blue: 23 / 255), location: 0.55),
                    .init(color: Color(red: 42 / 255, green: 36 / 255, blue: 31 / 255), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    Spacer()
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(height: 2)
                }
            )

            // Back Button (Leading aligned with viewfinder: left: 64px, top: 19px)
            Button {
                flowViewModel.returnToHomepage()
            } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(white: 0.15))
                            .offset(x: -1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return to Homepage")
            .position(x: viewfinderLeadingOffset + 22, y: 19 + 22)

            // Zoom Control (Back camera only: left: 537px, top: 0px, width: 172px, height: 83px, Figma 1302:47985)
            if !camera.isUsingFrontCamera {
                VStack(spacing: 4) {
                    Text(String(format: "ZOOM %.1fx", camera.zoomFactor))
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.88)
                        .foregroundStyle(Color(red: 185 / 255, green: 181 / 255, blue: 173 / 255))

                    KnurledZoomWheelView(
                        capabilities: camera.zoomCapabilities,
                        zoomFactor: camera.zoomFactor,
                        isEnabled: true,
                        onZoomChanged: { camera.setZoomFactor($0) },
                        onLensSelected: { camera.rampZoom(to: $0) }
                    )
                }
                .frame(width: 172, height: 83)
                .position(x: 537 + 172 / 2, y: 83 / 2)
            }

            // Info Button (Trailing: left: 789px, top: 22px, size: 44px, Figma 1302:48002)
            Button {
                flowViewModel.presentInviteFriends()
            } label: {
                ZStack {
                    Image("CameraInfoRing")
                        .resizable()
                        .frame(width: 44, height: 44)

                    Text("i")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Color(red: 235 / 255, green: 203 / 255, blue: 107 / 255))
                        .offset(y: -1)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show Roll Invite Code")
            .position(x: 789 + 22, y: 22 + 22)
        }
        .frame(width: 875, height: 83)
    }

    // MARK: - Screen Bezel & Live Preview (Figma 1302:47969)

    private var screenBezelView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14.5)
                .fill(Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255))
                .overlay(
                    RoundedRectangle(cornerRadius: 14.5)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 5.2, x: 0, y: 5.2)

            // Live Preview with Roll Filter
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

                // Viewfinder HUD
                VStack {
                    // Top-Left: Participant presence badge (per user instruction)
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("\(flowViewModel.participantCount)")
                                .font(.system(size: 11.4, weight: .semibold))
                                .tracking(0.9)

                            if flowViewModel.showsOfflineStatus {
                                Text("• \(flowViewModel.queuedShotCount) queued")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(ScrapTheme.cameraGold)
                            }
                        }
                        .foregroundStyle(Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255))
                        .padding(.horizontal, 8.3)
                        .padding(.vertical, 3.1)
                        .background(
                            RoundedRectangle(cornerRadius: 4.14)
                                .fill(Color.black.opacity(0.62))
                        )

                        Spacer()
                    }
                    .padding(.top, 10.36)
                    .padding(.leading, 10.36)

                    if let banner = flowViewModel.hostHandoverBanner {
                        Text(banner)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ScrapTheme.cameraGold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.75)))
                    }

                    Spacer()

                    // Bottom HUD row: Host End Roll & Debug buttons
                    HStack(spacing: 8) {
                        if isHost {
                            Button {
                                flowViewModel.endSessionManuallyByHost(
                                    currentUser: currentUser
                                )
                            } label: {
                                Text("END ROLL")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(ScrapTheme.indicatorRed.opacity(0.85))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        #if DEBUG
                        Button {
                            showsDebugLastShot = true
                        } label: {
                            Text("DEBUG: LAST SHOT")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.purple.opacity(0.85))
                                )
                        }
                        .buttonStyle(.plain)
                        #endif

                        Spacer()
                    }
                    .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6.2))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 487, height: 251)
    }

    // MARK: - Bottom Controls (Equal Spacing)

    private var bottomControlsRow: some View {
        HStack(spacing: 0) {
            // Flash toggle
            Button {
                camera.cycleFlash()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: camera.flashChoice == .off ? "bolt.slash" : (camera.flashChoice == .on ? "bolt.fill" : "bolt.badge.automatic"))
                        .font(.system(size: 14, weight: .bold))
                    Text(camera.flashChoice == .auto ? "FLASH AUTO" : "FLASH")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(
                    camera.flashChoice == .off
                        ? Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255).opacity(0.7)
                        : ScrapTheme.cameraGold
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            // LIVE toggle
            Button {
                camera.isLivePhotoEnabled.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "livephoto")
                        .font(.system(size: 14, weight: .bold))
                    Text("LIVE")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(
                    camera.isLivePhotoEnabled
                        ? ScrapTheme.cameraGold
                        : Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255).opacity(0.4)
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            // Flip camera button
            Button {
                camera.toggleCameraPosition()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: 14, weight: .bold))
                    Text("FLIP")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 487)
    }

    // MARK: - Shutter Well & Button (Figma 1302:47961)

    private var shutterWellView: some View {
        ZStack {
            // Recessed Well from Figma (107x107)
            Image("CameraShutterWell")
                .resizable()
                .frame(width: 107, height: 107)

            // Metallic circular shutter button
            Button {
                Task {
                    await flowViewModel.shutterTapped(currentUser: currentUser)
                }
            } label: {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white,
                                Color(white: 0.72),
                                Color(white: 0.42)
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 38
                        )
                    )
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 4)
            }
            .buttonStyle(ShutterButtonStyle(isProgrammaticallyPressed: flowViewModel.isShutterPressed))
        }
        .frame(width: 107, height: 107)
    }
}

private struct ShutterButtonStyle: ButtonStyle {
    let isProgrammaticallyPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed || isProgrammaticallyPressed
        configuration.label
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .opacity(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.65), value: isPressed)
            .contentShape(Circle())
    }
}
