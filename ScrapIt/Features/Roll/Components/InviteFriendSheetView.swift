import SwiftUI
import UIKit

/// Invite Friends sheet (change 019), host only, opened from the "+" tile.
/// Page 1 (Figma 1300:26163): Invite via AirDrop / Invite via Room Code.
/// Page 2 (Figma 1300:26710): the room code; long-press copies it.
struct InviteFriendSheetView: View {
    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel
    @State private var hasCopied = false

    var body: some View {
        VStack(spacing: 0) {
            switch flowViewModel.invitePage {
            case .options:
                optionsPage
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .code:
                codePage
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: flowViewModel.invitePage)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DSColor.Kraft.lightActive.color)
        .sheet(isPresented: $flowViewModel.isAirDropSheetPresented) {
            if let content = flowViewModel.inviteContent {
                RollInviteShareSheet(content: content, airDropOnly: true)
                    .presentationDetents([.medium, .large])
            }
        }
        .alert(
            flowViewModel.shareErrorMessage ?? "",
            isPresented: Binding(
                get: { flowViewModel.shareErrorMessage != nil },
                set: { if !$0 { flowViewModel.shareErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Page 1

    private var optionsPage: some View {
        VStack(spacing: 0) {
            header(leading: Button {
                flowViewModel.isInviteSheetPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DSColor.Brand.primary.color.opacity(0.6))
            }.accessibilityLabel("Close"))

            InviteFriendsIllustration()
                .frame(maxWidth: 376)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            Spacer(minLength: 16)

            VStack(spacing: 24) {
                Button("Invite via AirDrop") {
                    Task { await flowViewModel.inviteViaAirDrop(currentUser: currentUser) }
                }
                .buttonStyle(OffsetPillButtonStyle())
                .disabled(flowViewModel.isCreatingInviteLink)

                Button("Invite via Room Code") {
                    flowViewModel.showRoomCode()
                }
                .buttonStyle(OffsetPillButtonStyle())
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Page 2

    private var codePage: some View {
        VStack(spacing: 0) {
            header(leading: Button {
                flowViewModel.showInviteOptions()
            } label: {
                Image(systemName: "chevron.backward.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DSColor.Brand.primary.color.opacity(0.6))
            }.accessibilityLabel("Back"))

            Text("Share this code with your friends to join the roll.")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
                .padding(.top, 28)

            Image("InviteStars")
                .resizable()
                .scaledToFit()
                .frame(width: 213, height: 162)
                .padding(.top, 24)
                .accessibilityHidden(true)

            Text(flowViewModel.roomCode)
                .font(.system(size: 36, weight: .regular))
                .tracking(12)
                .foregroundStyle(Color.primary)
                .padding(.top, 24)
                .contentShape(Rectangle())
                .onLongPressGesture {
                    UIPasteboard.general.string = flowViewModel.roomCode
                    withAnimation(.easeInOut(duration: 0.2)) { hasCopied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeInOut(duration: 0.2)) { hasCopied = false }
                    }
                }
                .sensoryFeedback(.success, trigger: hasCopied) { _, copied in copied }
                .accessibilityLabel("Room code \(flowViewModel.roomCode)")
                .accessibilityHint("Long press to copy")

            Text("Copied")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DSColor.Component.textSecondary.color)
                .opacity(hasCopied ? 1 : 0)
                .padding(.top, 8)

            Spacer(minLength: 16)
        }
    }

    private func header(leading: some View) -> some View {
        ZStack {
            Text("Invite Friends")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DSColor.Brand.primary.color)
            HStack {
                leading
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}
