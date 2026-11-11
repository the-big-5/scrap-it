import SwiftUI
import UIKit

/// Multi-step full-screen return transition from camera session to homepage workbench (change 086).
/// Sits at MainShellView overlay level (above NavigationStack), preventing navigation pop artifacts and duplicate elements.
struct CameraReturnTransitionOverlay: View {
    let router: AppRouter
    @State private var backgroundOpacity: Double = 0.0
    @State private var cameraOpacity: Double = 0.0
    @State private var isZoomed: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let layout = WorkbenchLayout(container: proxy.size)
            let size = WorkbenchLayout.cameraSize
            let zoomedScale = WorkbenchLayout.zoomedCameraScale(
                container: proxy.size,
                layoutScale: layout.scale,
                angle: router.cameraReturnAngle
            )

            let targetPosition = isZoomed
                ? WorkbenchLayout.zoomedCameraCenter(
                    container: proxy.size,
                    layoutScale: layout.scale,
                    angle: router.cameraReturnAngle,
                    scale: zoomedScale
                )
                : layout.point(WorkbenchLayout.cameraIdleCenter)
            let targetRotation = isZoomed
                ? router.cameraReturnAngle
                : WorkbenchLayout.cameraIdleRotation
            let targetScale = isZoomed ? zoomedScale : 1.0

            ZStack {
                Color(red: 42 / 255, green: 36 / 255, blue: 31 / 255)
                    .ignoresSafeArea()
                    .opacity(backgroundOpacity)

                Image("DeskDisposableCamera")
                    .resizable()
                    .scaledToFit()
                    .frame(width: layout.length(size.width), height: layout.length(size.height))
                    .scaleEffect(targetScale)
                    .rotationEffect(.degrees(targetRotation))
                    .shadow(
                        color: .black.opacity(isZoomed ? 0 : 0.22),
                        radius: isZoomed ? 0 : 8,
                        x: 0,
                        y: isZoomed ? 0 : 4
                    )
                    .position(targetPosition)
                    .opacity(cameraOpacity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
        }
        .ignoresSafeArea()
        .task {
            // Step 1: Pure cross-fade into full-screen camera element with matching orientation
            withAnimation(.easeInOut(duration: 0.26)) {
                cameraOpacity = 1.0
                backgroundOpacity = 1.0
            }
            try? await Task.sleep(nanoseconds: 260_000_000)

            // Silently pop navigation stack underneath the fully opaque overlay
            UIView.setAnimationsEnabled(false)
            router.popToRoot()
            DispatchQueue.main.async {
                UIView.setAnimationsEnabled(true)
            }

            // Snappy hold delay after fading to zoomed-in camera before fading out the background
            try? await Task.sleep(nanoseconds: 140_000_000)

            // Step 2: Fade out the camera background, revealing the homepage underneath
            withAnimation(.easeInOut(duration: 0.24)) {
                backgroundOpacity = 0.0
            }
            try? await Task.sleep(nanoseconds: 240_000_000)

            // Snappy hold delay after fading out background before performing the back to homepage animation
            try? await Task.sleep(nanoseconds: 140_000_000)

            // Step 3: Smooth spring animation returning camera element to idle cutting mat position
            router.animateCameraReturnToIdle()
            withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                isZoomed = false
            }

            // Finish: clear overlay and restore floating tab bar
            try? await Task.sleep(nanoseconds: 460_000_000)
            router.finishCameraReturn()
        }
    }
}
