import SwiftUI

/// Roll lobby. Host (change 019, Figma 1282:21858): "⋯" menu (Edit Room, Share Room, Delete Room), "+" invite tile,
/// Start Roll, long-press Remove (011). Participant (Figma 1187:9657 / 1187:9798): "⋯" → Share Room, Leave Room.
struct CreateRollLobbyView: View {
    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    private static let ink = DSColor.Brand.primary.color

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
                                ForEach(row) { tile in
                                    switch tile {
                                    case .participant(let participant):
                                        avatar(participant)
                                    case .invite:
                                        inviteTile
                                    }
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
        .onAppear { flowViewModel.lobbyDidAppear(currentUser: currentUser) }
        .onDisappear { flowViewModel.lobbyDidDisappear() }
        .sheet(isPresented: $flowViewModel.isInviteSheetPresented) {
            InviteFriendSheetView(currentUser: currentUser, flowViewModel: flowViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // Share Room: the system share sheet straight away.
        .sheet(isPresented: $flowViewModel.isShareSheetPresented) {
            if let content = flowViewModel.inviteContent {
                RollInviteShareSheet(content: content)
                    .presentationDetents([.medium, .large])
            }
        }
        // An alert, not a confirmation dialog: on recent iOS a dialog can show as a popover without Cancel.
        .alert("Delete this room?", isPresented: $flowViewModel.isDeleteRoomConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Room", role: .destructive) { flowViewModel.deleteRoll() }
        } message: {
            Text("Everyone in the room will be removed.")
        }
        .alert(
            flowViewModel.shareErrorMessage ?? "",
            isPresented: Binding(
                get: { flowViewModel.shareErrorMessage != nil && !flowViewModel.isInviteSheetPresented },
                set: { if !$0 { flowViewModel.shareErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
    }

    private var rows: [[LobbyTile]] {
        let all = flowViewModel.lobbyTiles(currentUser: currentUser)
        return stride(from: 0, to: all.count, by: 3).map { Array(all[$0..<min($0 + 3, all.count)]) }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        // Top-aligned: the menu label below is 3 pt taller (it includes its shadow).
        HStack(alignment: .top) {
            CircleIconButton(systemName: "xmark", accessibilityLabel: "Close") {
                flowViewModel.closeLobby()
            }

            Spacer()

            Menu {
                if isHost {
                    // Edit Room has no action yet [Open].
                    Button("Edit Room", systemImage: "square.and.pencil") { flowViewModel.editRoom() }
                    shareRoomButton
                    Button("Delete Room", systemImage: "trash", role: .destructive) {
                        flowViewModel.requestDeleteRoom()
                    }
                } else {
                    shareRoomButton
                    Button("Leave Room", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        flowViewModel.leaveRoll(currentUser: currentUser)
                    }
                }
            } label: {
                // The 3 pt offset shadow sits outside the 44 pt circle; iOS clips a menu label to its frame
                // while the menu closes, so the shadow vanished for a moment. The padding keeps it inside.
                CircleIconLabel(systemName: "ellipsis")
                    .padding(.bottom, 3)
            }
            .menuOrder(.fixed)
            .accessibilityLabel("More")
        }
    }

    private var shareRoomButton: some View {
        Button("Share Room", systemImage: "square.and.arrow.up") {
            Task { await flowViewModel.shareRoom(currentUser: currentUser) }
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
        let isCurrentUser = participant.userID == currentUser.appleUserID
        let cell = RollAvatarView(
            participant: participant,
            isHost: participant.userID == session?.hostUserID,
            isCurrentUser: isCurrentUser,
            avatarData: isCurrentUser ? currentUser.avatarData : participant.avatarData
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

    /// Host's "+" tile (Figma 1300:26199): opens Invite Friends.
    private var inviteTile: some View {
        Button(action: flowViewModel.presentInviteFriends) {
            // SF Symbol instead of a "+" character: a text glyph sits off-center in its line height.
            Image(systemName: "plus")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DSColor.Paper.darker.color)
                .frame(width: 100, height: 100)
                .background(Circle().fill(DSColor.Paper.normalHover.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Invite friends")
    }

    // MARK: - Bottom

    @ViewBuilder
    private var bottom: some View {
        if isHost {
            Button("Start Roll") {
                flowViewModel.startRollCapture()
            }
            .buttonStyle(OffsetPillButtonStyle())
            .disabled(flowViewModel.activeSession?.status == .live)
        } else {
            Text("Waiting for the host to start...")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(DSColor.Paper.darkActive.color)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
    }
}
