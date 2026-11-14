import SwiftUI

struct CaptureSessionView: View {
    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var simulatedLandscapeSide: RollCameraOrientation.LandscapeSide = .left
    @State private var deviceOrientation: RollCameraOrientation.DeviceOrientation = .landscapeLeft
    @State private var zoomTextRotation: Double = 0.0
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

    var body: some View {
        CameraStage(
            camera: camera,
            deviceOrientation: $deviceOrientation,
            landscapeSide: $simulatedLandscapeSide,
            zoomTextRotation: $zoomTextRotation,
            onAppear: { flowViewModel.cameraDidAppear() },
            onDisappear: { flowViewModel.cameraDidDisappear() },
            canvas: {
                CameraBodyView(
                    camera: camera,
                    deviceOrientation: deviceOrientation,
                    zoomTextRotation: zoomTextRotation,
                    shotsRemaining: flowViewModel.shotsRemaining,
                    totalShots: flowViewModel.activeSession?.rollSize ?? 36,
                    isSyncingShot: flowViewModel.isSyncingShot,
                    isShutterPressed: flowViewModel.isShutterPressed,
                    isIrisClosing: isClosingIrisOnReturn,
                    hostHandoverBanner: flowViewModel.hostHandoverBanner,
                    isBackDisabled: flowViewModel.cameraReturnPhase != .idle || isClosingIrisOnReturn,
                    onBack: goBack,
                    onEndRoll: isHost ? { flowViewModel.presentEndRollConfirmation() } : nil,
                    onShutter: {
                        Task {
                            await flowViewModel.shutterTapped(currentUser: currentUser)
                        }
                    }
                )
            },
            overlay: { isPortraitWindow in
                ZStack {
                    if isAnyPopupPresented {
                        popupOverlay(isPortraitWindow: isPortraitWindow)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isAnyPopupPresented)
            }
        )
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
        // Camera access off (change 152): iOS won't ask again; back with access on, the camera starts.
        .alert("Camera Access Needed", isPresented: Bindable(camera).showsCameraAccessAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Turn on camera access in Settings to take photos for your roll.")
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await camera.startIfAccessGranted() }
        }
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

    private func goBack() {
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
