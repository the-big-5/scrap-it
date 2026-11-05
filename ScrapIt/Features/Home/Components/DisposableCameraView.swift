import SwiftUI

struct DisposableCameraView: View {
    let isActive: Bool
    let onTapCamera: () -> Void
    let onDismiss: () -> Void
    let onCreateRoll: () -> Void
    let onJoinRoll: () -> Void

    var body: some View {
        ZStack {
            // Dimmed backdrop blur when camera is active
            if isActive {
                Color.black.opacity(0.18)
                    .background(.ultraThinMaterial.opacity(0.4))
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            onDismiss()
                        }
                    }
                    .transition(.opacity)
            }

            // Camera + Action buttons container
            VStack(spacing: 16) {
                // Interactive Camera
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        onTapCamera()
                    }
                } label: {
                    Image("DeskDisposableCamera")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 291, height: 218)
                        .rotationEffect(.degrees(isActive ? 0.77 : -14.77))
                        .shadow(
                            color: .black.opacity(isActive ? 0.35 : 0.25),
                            radius: isActive ? 16 : 10,
                            x: 0,
                            y: isActive ? 8 : 4
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Disposable Camera")
                .accessibilityHint(isActive ? "Camera menu active" : "Tap to create or join a roll")
                .offset(
                    x: isActive ? 0 : -35,
                    y: isActive ? -10 : 0
                )

                // Popup action buttons (Figma node 984:3163)
                if isActive {
                    VStack(spacing: 14) {
                        Button(action: onCreateRoll) {
                            Text("Create Roll")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.12)) // #2A241F
                                .frame(width: 217, height: 52)
                                .background(
                                    ZStack {
                                        Capsule()
                                            .fill(Color(red: 0.16, green: 0.14, blue: 0.12))
                                            .offset(y: 7)

                                        Capsule()
                                            .fill(Color(red: 0.996, green: 0.996, blue: 0.992)) // #FEFEFD
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.black, lineWidth: 1.2)
                                            )
                                    }
                                )
                        }
                        .buttonStyle(.plain)

                        Button(action: onJoinRoll) {
                            Text("Join a Roll")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.12))
                                .frame(width: 217, height: 52)
                                .background(
                                    ZStack {
                                        Capsule()
                                            .fill(Color(red: 0.16, green: 0.14, blue: 0.12))
                                            .offset(y: 7)

                                        Capsule()
                                            .fill(Color(red: 0.996, green: 0.996, blue: 0.992))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.black, lineWidth: 1.2)
                                            )
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .position(
                x: 185,
                y: isActive ? 410 : 345
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
