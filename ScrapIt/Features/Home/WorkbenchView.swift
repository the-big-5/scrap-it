import SwiftData
import SwiftUI

struct WorkbenchView: View {
    @Bindable var viewModel: WorkbenchViewModel
    var scrapbooks: [Scrapbook]

    var body: some View {
        GeometryReader { proxy in
            let scaleX = proxy.size.width / 402.0
            let scaleY = proxy.size.height / 874.0

            ZStack {
                // Background: Complete flat-lay illustration (cutting mat, toolbox, ruler, books, etc.)
                // Blurs smoothly when the camera menu opens
                Image("WorkbenchBackgroundIdle")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blur(radius: viewModel.isCameraActive ? 12 : 0)
                    .overlay(
                        Color.black.opacity(viewModel.isCameraActive ? 0.18 : 0)
                    )
                    .clipped()

                // Dimmed backdrop tap gesture to dismiss active state
                if viewModel.isCameraActive {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
                                viewModel.dismissCamera()
                            }
                        }
                }

                // Interactive hit area: Stacked Tutorial Books (idle only)
                if !viewModel.isCameraActive {
                    Button {
                        viewModel.openTutorial()
                    } label: {
                        Color.clear
                            .frame(width: 170 * scaleX, height: 230 * scaleY)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: 100.0 * scaleX, y: 710.0 * scaleY)
                    .accessibilityLabel("Tutorial Book")
                    .accessibilityHint("Tap to open tutorial")
                }

                // Dynamic Disposable Camera
                // Spring rotates and animates from idle cutting mat spot to center
                Button {
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.76)) {
                        viewModel.toggleCamera()
                    }
                } label: {
                    Image("DeskDisposableCamera")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 291 * scaleX, height: 218 * scaleY)
                        .rotationEffect(.degrees(viewModel.isCameraActive ? 0.77 : -14.77))
                        .shadow(
                            color: .black.opacity(viewModel.isCameraActive ? 0.35 : 0.22),
                            radius: viewModel.isCameraActive ? 18 : 8,
                            x: 0,
                            y: viewModel.isCameraActive ? 10 : 4
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Disposable Camera")
                .accessibilityHint(viewModel.isCameraActive ? "Camera menu active" : "Tap to open roll menu")
                .position(
                    x: (viewModel.isCameraActive ? 155.0 : 112.0) * scaleX,
                    y: (viewModel.isCameraActive ? 335.0 : 450.0) * scaleY
                )

                // Popup action buttons: "Create Roll" & "Join a Roll" (spring up from bottom)
                if viewModel.isCameraActive {
                    VStack(spacing: 16) {
                        Button {
                            viewModel.startCreateRoll()
                        } label: {
                            Text("Create Roll")
                                .font(.system(size: 20 * min(scaleX, scaleY), weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.12)) // #2A241F
                                .frame(width: 217 * scaleX, height: 52 * scaleY)
                                .background(
                                    ZStack {
                                        Capsule()
                                            .fill(Color(red: 0.16, green: 0.14, blue: 0.12))
                                            .offset(y: 7 * scaleY)

                                        Capsule()
                                            .fill(Color(red: 0.996, green: 0.996, blue: 0.992)) // #FEFEFD
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.black, lineWidth: 1.5)
                                            )
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Create Roll")
                        .accessibilityHint("Start creating a new film roll")

                        Button {
                            viewModel.startJoinRoll()
                        } label: {
                            Text("Join a Roll")
                                .font(.system(size: 20 * min(scaleX, scaleY), weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.12))
                                .frame(width: 217 * scaleX, height: 52 * scaleY)
                                .background(
                                    ZStack {
                                        Capsule()
                                            .fill(Color(red: 0.16, green: 0.14, blue: 0.12))
                                            .offset(y: 7 * scaleY)

                                        Capsule()
                                            .fill(Color(red: 0.996, green: 0.996, blue: 0.992))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.black, lineWidth: 1.5)
                                            )
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Join a Roll")
                        .accessibilityHint("Join an existing roll using a code or link")
                    }
                    .position(x: 155.0 * scaleX, y: 495.0 * scaleY)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.40, dampingFraction: 0.78), value: viewModel.isCameraActive)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}
