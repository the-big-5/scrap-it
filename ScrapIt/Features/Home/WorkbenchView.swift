import SwiftData
import SwiftUI

/// Home Workbench (Figma 853:1703 Idle, 1062:3371 CameraClick), built from separate desk assets.
struct WorkbenchView: View {
    @Bindable var viewModel: WorkbenchViewModel
    var scrapbooks: [Scrapbook]

    var body: some View {
        ZStack(alignment: .topLeading) {
            workbench
                .ignoresSafeArea()

            // Figma CameraClick "Toolbar - Top", leading button: closes like tapping the blur.
            // Stays inside the safe area (below the status bar / Dynamic Island).
            if viewModel.isCameraActive {
                BackCircleButton { closeCamera() }
                    .accessibilityLabel("Close")
                    .padding(.leading, 16)
                    .transition(.opacity)
            }
        }
    }

    private var workbench: some View {
        GeometryReader { proxy in
            let layout = WorkbenchLayout(container: proxy.size)
            let isActive = viewModel.isCameraActive

            ZStack(alignment: .topLeading) {
                // Desk: every object is its own asset, placed at its Figma frame.
                // Blurs and dims when the camera menu opens.
                desk(layout)
                    // Flatten the whole desk into one image first, then blur it: one even full-page blur
                    // (like the Figma CameraClick background blur) instead of each object blurred on its own.
                    .drawingGroup()
                    // Opaque blur: the screen edges do not fade to the background color.
                    .blur(radius: isActive ? 12 : 0, opaque: true)
                    .overlay(Color.black.opacity(isActive ? 0.18 : 0))

                // Tap on the blurred desk closes the camera menu.
                if isActive {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { closeCamera() }
                }

                camera(layout, isActive: isActive)

                if isActive {
                    actionButtons(layout)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .animation(.spring(response: 0.40, dampingFraction: 0.78), value: isActive)
        }
        .background(Color(red: 0.604, green: 0.333, blue: 0.192)) // #9A5531, Figma frame fill behind the desk
    }

    // MARK: - Desk

    private func desk(_ layout: WorkbenchLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(WorkbenchLayout.deskItems, id: \.asset) { item in
                deskImage(item, layout)
                    .position(center(of: item.frame, layout))
                    .allowsHitTesting(false)
            }

            // Tutorial book: the book image itself is the button.
            Button {
                viewModel.openTutorial()
            } label: {
                deskImage(WorkbenchLayout.tutorialBook, layout)
            }
            .buttonStyle(.plain)
            .position(center(of: WorkbenchLayout.tutorialBook.frame, layout))
            .disabled(viewModel.isCameraActive)
            .accessibilityLabel("Tutorial Book")
            .accessibilityHint("Tap to open tutorial")
        }
    }

    private func deskImage(_ item: DeskItem, _ layout: WorkbenchLayout) -> some View {
        let frame = layout.rect(item.frame)
        return Image(item.asset)
            .resizable()
            .frame(width: frame.width, height: frame.height)
    }

    private func center(of rect: CGRect, _ layout: WorkbenchLayout) -> CGPoint {
        let frame = layout.rect(rect)
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    // MARK: - Camera

    /// Spring-rotates and moves from its spot on the cutting mat to the center (unchanged behavior).
    private func camera(_ layout: WorkbenchLayout, isActive: Bool) -> some View {
        let size = WorkbenchLayout.cameraSize
        return Button {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.76)) {
                viewModel.toggleCamera()
            }
        } label: {
            Image("DeskDisposableCamera")
                .resizable()
                .scaledToFit()
                .frame(width: layout.length(size.width), height: layout.length(size.height))
                .rotationEffect(.degrees(isActive ? WorkbenchLayout.cameraActiveRotation : WorkbenchLayout.cameraIdleRotation))
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
        .position(layout.point(isActive ? WorkbenchLayout.cameraActiveCenter : WorkbenchLayout.cameraIdleCenter))
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
        .position(layout.point(WorkbenchLayout.actionButtonsCenter))
    }

    private func actionButton(_ title: String, hint: String, layout: WorkbenchLayout, action: @escaping () -> Void) -> some View {
        let size = WorkbenchLayout.actionButtonSize
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
