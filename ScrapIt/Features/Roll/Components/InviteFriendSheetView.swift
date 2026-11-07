import SwiftUI
import UIKit

/// Invite friend sheet (Figma 1068:4233): roll code, Copy link, share button. Host only. No QR code.
struct InviteFriendSheetView: View {
    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel
    @State private var hasCopied = false

    private var codeCharacters: [String] {
        let chars = Array((flowViewModel.activeSession?.rollCode ?? "").uppercased())
        return (0..<6).map { $0 < chars.count ? String(chars[$0]) : "" }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemName: "xmark", accessibilityLabel: "Close") {
                    flowViewModel.isInviteSheetPresented = false
                }
                Spacer()
                Text("Invite friend")
                    .font(.headline)
                    .foregroundStyle(DSColor.Brand.primary.color)
                Spacer()
                CircleIconButton(systemName: "square.and.arrow.up", accessibilityLabel: "Share invite") {
                    flowViewModel.isShareSheetPresented = true
                }
                .disabled(flowViewModel.inviteContent == nil)
                .opacity(flowViewModel.inviteContent == nil ? 0.4 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)

            Spacer(minLength: 24)

            Text("Roll code:")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Color.black)
                .padding(.bottom, 16)

            HStack(spacing: 5) {
                ForEach(Array(codeCharacters.enumerated()), id: \.offset) { _, character in
                    RollCodeBox { Text(character) }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Roll code \(codeCharacters.joined())")

            Button {
                UIPasteboard.general.string = flowViewModel.inviteCopyText
                withAnimation(.easeInOut(duration: 0.2)) { hasCopied = true }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(.easeInOut(duration: 0.2)) { hasCopied = false }
                }
            } label: {
                Text(hasCopied ? "Copied!" : "Copy link")
                    .font(.system(size: 20, weight: .light))
                    .underline()
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .padding(.top, 28)

            // Link state: preparing, or failed with a retry [Draft].
            if flowViewModel.isCreatingInviteLink {
                ProgressView()
                    .padding(.top, 16)
            } else if let error = flowViewModel.inviteLinkError {
                VStack(spacing: 8) {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(DSColor.State.error.color)
                        .multilineTextAlignment(.center)
                    Button("Try again") {
                        Task { await flowViewModel.createInviteLinkIfNeeded(currentUser: currentUser) }
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .task { await flowViewModel.createInviteLinkIfNeeded(currentUser: currentUser) }
        .sheet(isPresented: $flowViewModel.isShareSheetPresented) {
            if let content = flowViewModel.inviteContent {
                RollInviteShareSheet(content: content)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}
