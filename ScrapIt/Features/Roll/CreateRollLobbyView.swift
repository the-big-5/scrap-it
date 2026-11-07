import SwiftUI

/// Roll lobby (change 011). Host: Figma 1011:5883 (invite, Delete roll, Start Roll, long-press Remove 1011:6043).
/// Participant: Figma 768:1291 ("⋯" → Leave roll 1129:8947, waiting text).
struct CreateRollLobbyView: View {
    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    private static let ink = DSColor.Brand.primary.color
    /// Figma "rednormal" (#AE1C1C).
    private static let deleteRed = Color(red: 0.682, green: 0.110, blue: 0.110)

    private var isHost: Bool {
        flowViewModel.isHost(currentUser)
    }

    private var session: CaptureSession? {
        flowViewModel.activeSession
    }

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            RollRoomHeader()

            VStack(alignment: .leading, spacing: 0) {
                toolbar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                header
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                // 3 avatars per row (Figma columns at x 27 / 147 / 267). Rooms are small, so no lazy grid.
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(rows, id: \.first?.id) { row in
                            HStack(alignment: .top, spacing: 20) {
                                ForEach(row) { participant in
                                    avatar(participant)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 27)
                    .padding(.top, 24)
                }

                bottom
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { flowViewModel.lobbyDidAppear() }
        .onDisappear { flowViewModel.lobbyDidDisappear() }
        .sheet(isPresented: $flowViewModel.isInviteSheetPresented) {
            InviteFriendSheetView(currentUser: currentUser, flowViewModel: flowViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var rows: [[RoomParticipant]] {
        let all = flowViewModel.lobbyParticipants
        return stride(from: 0, to: all.count, by: 3).map { Array(all[$0..<min($0 + 3, all.count)]) }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            CircleIconButton(systemName: "xmark", accessibilityLabel: "Close") {
                flowViewModel.closeLobby()
            }

            Spacer()

            if isHost {
                CircleIconButton(systemName: "person.badge.plus", accessibilityLabel: "Invite friend") {
                    flowViewModel.isInviteSheetPresented = true
                }
            } else {
                Menu {
                    Button("Leave roll", role: .destructive) {
                        flowViewModel.leaveRoll(currentUser: currentUser)
                    }
                } label: {
                    CircleIconLabel(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session?.name ?? "")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Self.ink)
                .lineLimit(1)

            HStack(spacing: 16) {
                Label("\(flowViewModel.lobbyJoinedCount) joined", systemImage: "person.2")
                    .font(.system(size: 18, weight: .bold))
                Label("\(session?.rollSize ?? 0) shots", systemImage: "camera")
                    .font(.system(size: 18, weight: .regular))
            }
            .labelStyle(.titleAndIcon)
            .foregroundStyle(DSColor.Component.textSecondary.color)
        }
    }

    // MARK: - Avatars

    @ViewBuilder
    private func avatar(_ participant: RoomParticipant) -> some View {
        let cell = RollAvatarView(
            participant: participant,
            isHost: participant.userID == session?.hostUserID,
            isCurrentUser: participant.userID == currentUser.appleUserID
        )
        if flowViewModel.canRemove(participant, currentUser: currentUser) {
            // Host long-press → Remove (no confirmation, user decision).
            cell.contextMenu {
                Button("Remove", role: .destructive) {
                    flowViewModel.removeParticipant(participant, currentUser: currentUser)
                }
            }
        } else {
            cell
        }
    }

    // MARK: - Bottom

    @ViewBuilder
    private var bottom: some View {
        if isHost {
            VStack(spacing: 16) {
                Button {
                    flowViewModel.deleteRoll()
                } label: {
                    Text("Delete roll")
                        .font(.system(size: 20, weight: .regular))
                        .underline()
                        .foregroundStyle(Self.deleteRed)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button("Start Roll") {
                    flowViewModel.startRollCapture()
                }
                .buttonStyle(OffsetPillButtonStyle())
            }
        } else {
            Text("Waiting for the host to start...")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(DSColor.Paper.darkActive.color)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
    }
}
