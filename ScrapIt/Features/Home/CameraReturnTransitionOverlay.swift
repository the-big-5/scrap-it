import SwiftUI
import UIKit

/// Math helpers for 3D camera horizontal flip return transition (change 100).
struct CameraFlipMath {
    static func isFrontFacing(angle: Double) -> Bool {
        angle >= 90.0
    }

    static func backAngle(for angle: Double) -> Double {
        angle
    }

    static func frontAngle(for angle: Double) -> Double {
        angle - 180.0
    }
}

/// Two-sided 3D animatable card flipping horizontally along local Y-axis (change 100).
struct CameraFlipCardView: View, Animatable {
    var angle: Double
    let layout: WorkbenchLayout
    let size: CGSize

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let isFront = CameraFlipMath.isFrontFacing(angle: angle)
        ZStack {
            if isFront {
                Image("DeskDisposableCamera")
                    .resizable()
                    .scaledToFit()
                    .frame(width: layout.length(size.width), height: layout.length(size.height))
                    .rotation3DEffect(
                        .degrees(CameraFlipMath.frontAngle(for: angle)),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.35
                    )
            } else {
                CameraReturnBackDeckView()
                    .frame(width: layout.length(size.width), height: layout.length(size.height))
                    .rotation3DEffect(
                        .degrees(CameraFlipMath.backAngle(for: angle)),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.35
                    )
            }
        }
    }
}

/// Physical disposable camera back face representation for the return transition (changes 100, 110).
struct CameraReturnBackDeckView: View {
    var body: some View {
        Image("DeskDisposableCameraBack")
            .resizable()
            .scaledToFit()
    }
}

/// Stages of camera scaling during the return transition (changes 086, 100).
enum CameraReturnScaleState {
    case fullBleed
    case floating
    case idle
}

/// Multi-step full-screen return transition from camera session to homepage workbench (changes 086, 100).
/// Sits at MainShellView overlay level (above NavigationStack), preventing navigation pop artifacts and duplicate elements.
struct CameraReturnTransitionOverlay: View {
    let router: AppRouter
    @State private var backgroundOpacity: Double = 1.0
    @State private var scaleState: CameraReturnScaleState = .fullBleed
    @State private var flipAngle: Double = 0.0

    var body: some View {
        GeometryReader { proxy in
            let layout = WorkbenchLayout(container: proxy.size)
            let size = layout.activeCameraSize

            let targetScale: CGFloat = switch scaleState {
            case .fullBleed:
                layout.fullBleedCameraScale(
                    container: proxy.size,
                    angle: router.cameraReturnAngle
                )
            case .floating:
                layout.floatingCameraScale(
                    container: proxy.size,
                    angle: router.cameraReturnAngle
                )
            case .idle:
                1.0
            }

            let targetPosition: CGPoint = switch scaleState {
            case .fullBleed:
                layout.zoomedViewfinderCenter(
                    container: proxy.size,
                    angle: router.cameraReturnAngle,
                    scale: targetScale
                )
            case .floating:
                layout.zoomedCameraCenter(
                    container: proxy.size,
                    angle: router.cameraReturnAngle,
                    scale: targetScale
                )
            case .idle:
                layout.point(layout.activeCameraIdleCenter)
            }

            let targetRotation: Double = switch scaleState {
            case .fullBleed, .floating:
                router.cameraReturnAngle
            case .idle:
                layout.activeCameraIdleRotation
            }

            let shadowOpacity: Double = switch scaleState {
            case .fullBleed: 0.0
            case .floating: 0.32
            case .idle: 0.22
            }

            let shadowRadius: CGFloat = switch scaleState {
            case .fullBleed: 0
            case .floating: 12
            case .idle: 8
            }

            let shadowY: CGFloat = switch scaleState {
            case .fullBleed: 0
            case .floating: 8
            case .idle: 4
            }

            ZStack {
                Color(red: 42 / 255, green: 36 / 255, blue: 31 / 255)
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity)

                CameraFlipCardView(angle: flipAngle, layout: layout, size: size)
                    .scaleEffect(targetScale)
                    .rotationEffect(.degrees(targetRotation))
                    .shadow(
                        color: .black.opacity(shadowOpacity),
                        radius: shadowRadius,
                        x: 0,
                        y: shadowY
                    )
                    .position(targetPosition)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
        }
        .ignoresSafeArea()
        .task {
            // Silently pop navigation stack underneath the fully opaque overlay
            UIView.setAnimationsEnabled(false)
            router.popToRoot()
            DispatchQueue.main.async {
                UIView.setAnimationsEnabled(true)
            }

            // Step 1: Smoothly resize from full-bleed cover down to floating camera card
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                scaleState = .floating
            }
            try? await Task.sleep(nanoseconds: 360_000_000)

            // Step 2: 3D Y-axis horizontal flip from camera back to front disposable camera
            withAnimation(.easeInOut(duration: 0.42)) {
                flipAngle = 180.0
            }
            try? await Task.sleep(nanoseconds: 420_000_000)

            // Step 3: Fade out the camera background, revealing the homepage underneath
            withAnimation(.easeInOut(duration: 0.24)) {
                backgroundOpacity = 0.0
            }
            try? await Task.sleep(nanoseconds: 240_000_000)

            // Step 4: Smooth spring animation returning camera element to idle cutting mat position
            router.animateCameraReturnToIdle()
            withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                scaleState = .idle
            }

            // Finish: clear overlay and restore floating tab bar
            try? await Task.sleep(nanoseconds: 460_000_000)
            router.finishCameraReturn()
        }
    }
}
