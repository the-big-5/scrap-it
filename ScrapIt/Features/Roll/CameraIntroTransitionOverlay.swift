import SwiftUI

/// Stages of the camera entrance intro animation (change 110).
enum CameraIntroStage: Equatable, Sendable {
    case fadeToBlank
    case arrival
    case loadingFilm
    case latching
    case winding
    case zoomToDeck
    case completed
}

/// Full-screen forward transition overlay displayed when entering camera after starting a roll (change 110).
/// References: CameraIntro.dc.html (5.6s loading sequence with 216 depth extrusions).
struct CameraIntroTransitionOverlay: View {
    let router: AppRouter
    let flowViewModel: RollFlowViewModel?

    @State private var stage: CameraIntroStage = .fadeToBlank
    @State private var blankPageOpacity: Double = 0.0
    @State private var is3DAnimationVisible: Bool = false
    @State private var overlayOpacity: Double = 1.0
    @State private var animationTask: Task<Void, Never>?

    private var filter: RollFilter {
        router.cameraIntroFilter
    }

    var body: some View {
        ZStack {
            // Stage 1: Full-screen blank cream paper background with vignette & grain
            CameraIntroPaperBackground(opacity: blankPageOpacity)

            // Stage 2: Hardware-accelerated 3D camera intro animation
            if is3DAnimationVisible {
                CameraIntroWebView(
                    filter: filter,
                    onZoomDeck: {
                        completeHandoffToCamera()
                    },
                    onComplete: {
                        finishIntro()
                    },
                    onSkip: {
                        skipIntro()
                    }
                )
                .ignoresSafeArea()
            }

            // Single clean skip hint without duplicate overlay
            if stage != .completed && stage != .fadeToBlank {
                CameraIntroSkipPromptView()
            }
        }
        .opacity(overlayOpacity)
        .contentShape(Rectangle())
        .onTapGesture {
            skipIntro()
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimationSequence()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    // MARK: - Animation Timeline Execution

    private func startAnimationSequence() {
        animationTask = Task {
            // Stage 1: Fade from CreateRollLobbyView to blank paper page
            stage = .fadeToBlank
            withAnimation(.easeInOut(duration: 0.35)) {
                blankPageOpacity = 1.0
            }

            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            // Silently advance navigation stack to .captureSession underneath the blank paper
            if router.path.last != .captureSession {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    router.push(.captureSession)
                }
            }

            // Stage 2: Begin 3D camera intro animation
            stage = .arrival
            router.setCameraIntroAnimating()
            is3DAnimationVisible = true
        }
    }

    private func completeHandoffToCamera() {
        stage = .zoomToDeck
        // As the 3D viewfinder fills the screen, dissolve into the live CaptureSessionView
        withAnimation(.easeOut(duration: 0.35)) {
            overlayOpacity = 0.0
        }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            finishIntro()
        }
    }

    private func finishIntro() {
        stage = .completed
        animationTask?.cancel()
        if router.path.last != .captureSession {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                router.push(.captureSession)
            }
        }
        router.finishCameraIntro()
    }

    private func skipIntro() {
        stage = .completed
        animationTask?.cancel()
        if router.path.last != .captureSession {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                router.push(.captureSession)
            }
        }
        router.finishCameraIntro()
    }
}
