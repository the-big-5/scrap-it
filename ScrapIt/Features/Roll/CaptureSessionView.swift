import SwiftData
import SwiftUI

struct CaptureSessionView: View {
    @Environment(\.modelContext) private var modelContext

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    private var camera: CameraController {
        flowViewModel.camera
    }

    private var isHost: Bool {
        flowViewModel.isHost(currentUser)
    }

    private var remainingShotsText: String {
        flowViewModel.remainingShotsText
    }

    private var totalShotsText: String {
        flowViewModel.totalShotsText
    }

    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width
            ZStack {
                Color.black.ignoresSafeArea()

                if isPortrait {
                    // Render the landscape camera body rotated 90° so it fills portrait phones naturally
                    // while also supporting true landscape rotation seamlessly
                    cameraBodyContent
                        .frame(width: geo.size.height, height: geo.size.width)
                        .rotationEffect(.degrees(90))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                } else {
                    cameraBodyContent
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(
            CaptureEventView(
                isEnabled: camera.isPreviewReady,
                onPrimary: {
                    Task {
                        await flowViewModel.shutterTapped(
                            currentUser: currentUser,
                            modelContext: modelContext
                        )
                    }
                },
                onSecondary: {
                    camera.cycleFlash()
                }
            )
        )
        .onAppear {
            flowViewModel.cameraDidAppear(modelContext: modelContext)
        }
        .onDisappear {
            flowViewModel.cameraDidDisappear()
        }
        .alert("Roll Finished", isPresented: $flowViewModel.showLastSlotRaceAlert) {
            Button("Open Scrapbook") {
                flowViewModel.finalizeSessionAndOpenScrapbook(modelContext: modelContext)
            }
        } message: {
            Text(flowViewModel.lastSlotRaceMessage)
        }
    }

    private var cameraBodyContent: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Top Black Camera Deck (Flash, Live, Viewfinder Housing, Advance, Shots Counter, Zoom Wheel, Shutter)
                topCameraDeck
                    .frame(height: 102)

                // Green Camera Body (Strap lugs, Viewfinder Screen, Tally dot + Flip + Grid, Right Grip)
                lowerGreenBody
                    .frame(maxHeight: .infinity)
            }

            // Optical viewfinder housing straddling the top deck and green body per Figma node 708:4941
            opticalViewfinderHousing
                .offset(x: -96, y: 8)
        }
    }

    // MARK: - Top Black Deck

    private var topCameraDeck: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.15), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 14) {
                // Flash toggle pill
                Button {
                    camera.cycleFlash()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(camera.flashChoice.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(ScrapTheme.cameraGold)
                    .frame(width: 96, height: 48)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.19))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                // LIVE toggle pill
                Button {
                    camera.isLivePhotoEnabled.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "livephoto")
                            .font(.system(size: 14, weight: .bold))
                        Text("LIVE")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(
                        camera.isLivePhotoEnabled
                            ? ScrapTheme.cameraGold
                            : Color.white.opacity(0.45)
                    )
                    .frame(width: 96, height: 48)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.19))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                // Space reserved for optical viewfinder housing
                Spacer()
                    .frame(width: 148)

                // Silver advance / host controls button (▶◀)
                Menu {
                    if isHost {
                        Button(role: .destructive) {
                            flowViewModel.endSessionManuallyByHost(
                                currentUser: currentUser,
                                modelContext: modelContext
                            )
                        } label: {
                            Label("End Roll Now (Host)", systemImage: "stop.circle.fill")
                        }
                    }
                    Button {
                        flowViewModel.simulateHostDisconnect(modelContext: modelContext)
                    } label: {
                        Label("Simulate Host Disconnect Handover", systemImage: "person.badge.key.fill")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                            .rotationEffect(.degrees(180))
                    }
                    .foregroundStyle(Color(white: 0.55))
                    .frame(width: 68, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.90), Color(white: 0.78)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                }

                // Shots Counter (09 /36 SHOTS)
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(remainingShotsText)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(ScrapTheme.cameraGold)
                        Text(totalShotsText)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .frame(width: 78, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(white: 0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )

                    Text("SHOTS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                // Knurled Zoom Wheel (ZOOM 1.0x)
                VStack(spacing: 4) {
                    KnurledZoomWheelView(zoomFactor: camera.zoomFactor) { newZoom in
                        camera.setZoomFactor(newZoom, ramp: true)
                    }

                    Text(String(format: "ZOOM %.1fx", camera.zoomFactor))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                // Metallic Circular Shutter Button
                Button {
                    Task {
                        await flowViewModel.shutterTapped(
                            currentUser: currentUser,
                            modelContext: modelContext
                        )
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.08))
                            .frame(width: 74, height: 74)
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
                                    endRadius: 32
                                )
                            )
                            .frame(width: 56, height: 56)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }
    }

    private var opticalViewfinderHousing: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.18), Color(white: 0.09)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 142, height: 112)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 4)

            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.04))
                .frame(width: 92, height: 68)

            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.10),
                            Color(red: 0.16, green: 0.20, blue: 0.20),
                            Color(white: 0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 52, height: 34)
        }
    }

    // MARK: - Lower Green Camera Body

    private var lowerGreenBody: some View {
        ZStack {
            ScrapTheme.cameraGreen

            HStack(spacing: 18) {
                // Left strap lugs
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color(white: 0.10))
                        .frame(width: 14, height: 58)
                    Capsule()
                        .fill(Color(white: 0.10))
                        .frame(width: 14, height: 58)
                }
                .padding(.leading, 18)

                // Main Viewfinder Screen (No other users' photos shown — only own viewfinder)
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(white: 0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(white: 0.12), lineWidth: 8)
                        )

                    #if canImport(UIKit)
                    if camera.isPreviewReady {
                        CameraPreviewLayerView(session: camera.captureSession)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(6)
                    }
                    #endif

                    // Rule-of-thirds Grid Overlay when GRID button is active
                    if camera.isGridVisible {
                        CameraGridOverlay()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(6)
                    }

                    // Shutter flash feedback
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(camera.shutterFlashOpacity))
                        .animation(.easeOut(duration: 0.1), value: camera.shutterFlashOpacity)
                        .padding(6)
                        .allowsHitTesting(false)

                    // Viewfinder HUD overlays (LIVE badge, presence & offline indicator, zoom badge)
                    VStack {
                        HStack {
                            if camera.isLivePhotoEnabled {
                                Text("LIVE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.black.opacity(0.65))
                                    )
                            }

                            Spacer()

                            // Live presence count & offline queue status
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 10))
                                Text("\(flowViewModel.participantCount)")
                                    .font(.system(size: 11, weight: .semibold))

                                if flowViewModel.showsOfflineStatus {
                                    Text("• \(flowViewModel.queuedShotCount) queued")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(ScrapTheme.cameraGold)
                                }
                            }
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.65))
                            )
                        }

                        if let banner = flowViewModel.hostHandoverBanner {
                            Text(banner)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ScrapTheme.cameraGold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.75)))
                        }

                        Spacer()

                        HStack {
                            if isHost {
                                Button {
                                    flowViewModel.endSessionManuallyByHost(
                                        currentUser: currentUser,
                                        modelContext: modelContext
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

                            Spacer()

                            Text(String(format: "%.1fx", camera.zoomFactor))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ScrapTheme.cameraGold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black.opacity(0.65))
                                )
                        }
                    }
                    .padding(18)
                }
                .frame(maxWidth: 490)
                .padding(.vertical, 16)

                // Right Column Controls: Red tally dot, FLIP button, GRID button
                VStack(spacing: 18) {
                    Circle()
                        .fill(ScrapTheme.indicatorRed)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.85), lineWidth: 2.5)
                        )
                        .padding(.bottom, 4)

                    // FLIP camera button
                    Button {
                        camera.toggleCameraPosition()
                    } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.10))
                                    .frame(width: 54, height: 54)
                                    .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(ScrapTheme.cameraGold)
                            }
                            Text("FLIP")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    // GRID overlay button
                    Button {
                        camera.isGridVisible.toggle()
                    } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.10))
                                    .frame(width: 54, height: 54)
                                    .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
                                Image(systemName: "squareshape.split.3x3")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(
                                        camera.isGridVisible
                                            ? ScrapTheme.cameraGold
                                            : ScrapTheme.cameraGold.opacity(0.65)
                                    )
                            }
                            Text("GRID")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)

                // Molded Right Hand Grip
                RoundedRectangle(cornerRadius: 28)
                    .fill(ScrapTheme.cameraDarkGreen)
                    .frame(width: 190)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.black.opacity(0.25), lineWidth: 2)
                    )
                    .padding(.vertical, 14)
                    .padding(.trailing, -24)
            }
        }
    }
}
