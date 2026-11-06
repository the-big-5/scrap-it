import SwiftUI

struct CreateRollLobbyView: View {
    @Environment(\.dismiss) private var dismiss

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    private var isHost: Bool {
        flowViewModel.isHost(currentUser)
    }

    private var session: CaptureSession? {
        flowViewModel.activeSession
    }

    private var participants: [(id: String, name: String)] {
        guard let session else { return [] }
        var result: [(id: String, name: String)] = []
        let ids = session.participantIDs
        let names = session.participantNames
        for i in 0..<ids.count {
            let id = ids[i]
            let name = i < names.count ? names[i] : "Friend"
            result.append((id: id, name: name))
        }
        return result
    }

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            // Header decoration from Figma nodes 1011:5883 / 768:1382
            Image("ShareRoomHeaderDecoration")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 206)
                .clipped()
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 0) {
                // Top navigation bar with Back button, Title, and Invite Button
                HStack {
                    BackCircleButton {
                        dismiss()
                    }

                    Spacer()

                    Text("Share Room")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)

                    Spacer()

                    // Top-right invite button triggering the Invite Friend Sheet
                    Button {
                        flowViewModel.isInviteSheetPresented = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(DSColor.Paper.light.color)
                                .frame(width: 44, height: 44)
                                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)

                            Image(systemName: "qrcode")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(DSColor.Brand.primary.color)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 18)

                // Header Info: Roll Name + Stats Row
                VStack(alignment: .leading, spacing: 8) {
                    Text(session?.name ?? "My Roll")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)
                        .lineLimit(1)

                    HStack(spacing: 18) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2")
                                .font(.system(size: 17, weight: .bold))
                            Text("\(participants.count) joined")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(DSColor.Component.textSecondary.color)

                        HStack(spacing: 6) {
                            Image(systemName: "camera")
                                .font(.system(size: 17, weight: .regular))
                            Text("\(session?.rollSize ?? 36) shots")
                                .font(.system(size: 17, weight: .regular))
                        }
                        .foregroundStyle(DSColor.Component.textSecondary.color)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)

                // Dynamic Participant Avatar Grid
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 24
                    ) {
                        ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                            participantAvatarCell(
                                id: participant.id,
                                name: participant.name,
                                index: index
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                Spacer()

                // Primary Start Roll Button
                VStack(spacing: 8) {
                    if isHost {
                        Button("Start Roll") {
                            flowViewModel.startRollCapture()
                        }
                        .buttonStyle(OffsetPillButtonStyle())
                    } else {
                        // Guest view: waiting for host to start
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(DSColor.Brand.primary.color.opacity(0.6))
                            Text("Waiting for host to start...")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(DSColor.Brand.primary.color.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(DSColor.Paper.light.color.opacity(0.7))
                                .overlay(
                                    Capsule()
                                        .stroke(DSColor.Brand.primary.color.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $flowViewModel.isInviteSheetPresented) {
            InviteFriendSheetView(
                rollCode: session?.rollCode ?? "",
                inviteURL: session?.inviteURL,
                qrPayload: flowViewModel.lobbyQRPayload
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Avatar Cell Builder

    @ViewBuilder
    private func participantAvatarCell(id: String, name: String, index: Int) -> some View {
        let isHostParticipant = (id == session?.hostUserID)
        let isCurrent = (id == currentUser.appleUserID)

        VStack(spacing: 6) {
            ZStack {
                // Background & image / monogram
                if isCurrent, let avatarData = currentUser.avatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                } else {
                    let backgroundFill = avatarColor(for: index)
                    let textFill = avatarTextColor(for: index)
                    let initial = String(name.prefix(1)).uppercased()

                    Circle()
                        .fill(backgroundFill)
                        .frame(width: 90, height: 90)

                    Text(initial.isEmpty ? "?" : initial)
                        .font(.system(size: 38, weight: .regular))
                        .foregroundStyle(textFill)
                }

                // Border ring
                Circle()
                    .stroke(DSColor.Brand.primary.color, lineWidth: 1.5)
                    .frame(width: 90, height: 90)
            }

            // Name
            Text(name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DSColor.Brand.primary.color)
                .lineLimit(1)

            // Subtitle indicator
            if isHostParticipant {
                Text("(Host)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DSColor.Brand.primary.color.opacity(0.7))
            } else if isCurrent {
                Text("(You)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DSColor.Brand.primary.color.opacity(0.7))
            } else {
                Text(" ")
                    .font(.system(size: 13))
            }
        }
    }

    private func avatarColor(for index: Int) -> Color {
        let colors = [
            DSColor.Paper.light.color,
            DSColor.Brand.tertiary.color,
            DSColor.Brand.secondary.color,
            DSColor.Kraft.darker.color
        ]
        return colors[index % colors.count]
    }

    private func avatarTextColor(for index: Int) -> Color {
        let colors = [
            DSColor.Brand.primary.color,
            DSColor.Paper.light.color,
            DSColor.Brand.primary.color,
            DSColor.Paper.light.color
        ]
        return colors[index % colors.count]
    }
}
