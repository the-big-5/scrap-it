import SwiftUI

/// The camera screen's stage (changes 072, 123): the matte, the `874 × 402` camera canvas scaled to the screen
/// and turned to reference landscape, the phone's orientation from motion (symbols turn, the body stays), and the
/// camera session's start / stop. Shared by the capture session and the camera tutorial (change 152). `overlay`
/// sits over the whole screen and gets whether the window is portrait.
struct CameraStage<Canvas: View, Overlay: View>: View {
    let camera: CameraController
    @Binding var deviceOrientation: RollCameraOrientation.DeviceOrientation
    @Binding var landscapeSide: RollCameraOrientation.LandscapeSide
    @Binding var zoomTextRotation: Double
    var onAppear: () -> Void = {}
    var onDisappear: () -> Void = {}
    @ViewBuilder let canvas: () -> Canvas
    @ViewBuilder let overlay: (_ isPortraitWindow: Bool) -> Overlay

    @State private var motionService = CameraMotionService()

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
                physicalSide: landscapeSide
            )

            // Figma design native canvas: 874 x 402 pt (matches iPhone Pro landscape dimensions)
            let canvasWidth: CGFloat = 874
            let canvasHeight: CGFloat = 402

            // iPhone stays flush edge-to-edge (max); iPad scales proportionally to fit without cropping (min).
            let scale = RollCameraOrientation.cameraCanvasScale(
                viewportSize: geo.size,
                canvasSize: CGSize(width: canvasWidth, height: canvasHeight)
            )

            ZStack {
                Color(red: 42 / 255, green: 36 / 255, blue: 31 / 255)
                    .ignoresSafeArea()

                canvas()
                    .frame(width: canvasWidth, height: canvasHeight)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotationDegrees))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                overlay(isPortrait)
            }
            .ignoresSafeArea()
            .onChange(of: isPortrait) { _, newIsPortrait in
                camera.setSimulatedLandscapeSide(
                    landscapeSide,
                    isPortrait: newIsPortrait,
                    windowOrientation: windowOrientation,
                    deviceOrientation: deviceOrientation
                )
            }
            .onChange(of: landscapeSide) { _, newSide in
                camera.setSimulatedLandscapeSide(
                    newSide,
                    isPortrait: isPortrait,
                    windowOrientation: windowOrientation,
                    deviceOrientation: deviceOrientation
                )
            }
            .onChange(of: deviceOrientation) { _, newOrientation in
                camera.setSimulatedLandscapeSide(
                    landscapeSide,
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
                    if let side = newOrientation.landscapeSide, side != landscapeSide {
                        landscapeSide = side
                    }
                    zoomTextRotation = RollCameraOrientation.zoomTextRotationDegrees(
                        for: newOrientation,
                        previousRotation: zoomTextRotation
                    )
                }
                camera.setSimulatedLandscapeSide(
                    landscapeSide,
                    isPortrait: isPortrait,
                    windowOrientation: windowOrientation,
                    deviceOrientation: deviceOrientation
                )
                OrientationLock.set(.portrait)
                onAppear()
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
                onDisappear()
            }
        }
        .ignoresSafeArea()
    }
}
