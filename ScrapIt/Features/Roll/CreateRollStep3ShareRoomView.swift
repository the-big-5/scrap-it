import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct CreateRollStep3ShareRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Create Roll")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ScrapTheme.charcoal)

                    HStack {
                        BackCircleButton {
                            dismiss()
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 34)

                // Framed QR Code
                QRCodeBracketView(payload: flowViewModel.lobbyQRPayload)
                    .frame(width: 174, height: 174)
                    .padding(.bottom, 26)

                // Roll Code Boxes
                Text("Roll code:")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(ScrapTheme.charcoal)
                    .padding(.bottom, 10)

                HStack(spacing: 6) {
                    ForEach(Array(flowViewModel.lobbyRollCodeCharacters.enumerated()), id: \.offset) { _, ch in
                        Text(ch)
                            .font(.system(size: 26, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ScrapTheme.charcoal)
                            .frame(width: 48, height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(ScrapTheme.charcoal, lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.bottom, 18)

                Text("or")
                    .font(.system(size: 16))
                    .foregroundStyle(ScrapTheme.charcoal)
                    .padding(.bottom, 14)

                if let inviteURL = flowViewModel.activeSession?.inviteURL {
                    ShareLink(
                        item: inviteURL,
                        subject: Text("Join my ScrapIt Roll"),
                        message: Text("Join our shared camera roll with code \(flowViewModel.activeSession?.rollCode ?? "")!")
                    ) {
                        Text("Share link")
                            .font(.system(size: 18, weight: .bold))
                            .underline()
                            .foregroundStyle(ScrapTheme.charcoal)
                    }
                    .padding(.bottom, 38)
                }

                // Joined count
                HStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 16))
                        .foregroundStyle(ScrapTheme.secondaryText)
                    Text("\(flowViewModel.lobbyJoinedCount) Joined")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(ScrapTheme.secondaryText)
                }

                Spacer()

                Button("Start Roll") {
                    flowViewModel.startRollCapture(modelContext: modelContext)
                }
                .buttonStyle(OffsetPillButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
