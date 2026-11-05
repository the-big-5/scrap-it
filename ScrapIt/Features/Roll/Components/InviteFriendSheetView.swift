import SwiftUI
import UIKit

struct InviteFriendSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let rollCode: String
    let inviteURL: URL?
    let qrPayload: String

    @State private var hasCopied: Bool = false

    private var codeCharacters: [String] {
        let trimmed = rollCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let chars = Array(trimmed)
        if chars.count >= 6 {
            return (0..<6).map { String(chars[$0]) }
        } else {
            return (0..<6).map { i in
                i < chars.count ? String(chars[i]) : "•"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DSColor.Kraft.lightActive.color
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 16)

                    // Framed dynamic QR code matching node 768:1483
                    QRCodeBracketView(payload: qrPayload)
                        .frame(width: 190, height: 190)
                        .padding(.bottom, 22)

                    // Monospace roll code label and boxes
                    Text("Roll code:")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(DSColor.Brand.primary.color)
                        .padding(.bottom, 10)

                    HStack(spacing: 8) {
                        ForEach(Array(codeCharacters.enumerated()), id: \.offset) { _, char in
                            Text(char)
                                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DSColor.Brand.primary.color)
                                .frame(width: 48, height: 58)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(DSColor.Paper.light.color)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(DSColor.Brand.primary.color, lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.bottom, 20)

                    // Copy link button with clipboard action + ShareLink option
                    HStack(spacing: 16) {
                        Button {
                            copyLinkToClipboard()
                        } label: {
                            Text(hasCopied ? "Copied!" : "Copy link")
                                .font(.system(size: 17, weight: .regular))
                                .underline()
                                .foregroundStyle(hasCopied ? DSColor.Brand.tertiary.color : DSColor.Brand.primary.color)
                        }

                        if let inviteURL {
                            Text("·")
                                .foregroundStyle(DSColor.Brand.primary.color.opacity(0.4))

                            ShareLink(
                                item: inviteURL,
                                subject: Text("Join my ScrapIt Roll"),
                                message: Text("Join our shared camera roll with code \(rollCode)!")
                            ) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(DSColor.Brand.primary.color)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Invite friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(DSColor.Brand.primary.color.opacity(0.6))
                    }
                }
            }
        }
    }

    private func copyLinkToClipboard() {
        let stringToCopy = inviteURL?.absoluteString ?? rollCode
        UIPasteboard.general.string = stringToCopy
        withAnimation(.easeInOut(duration: 0.2)) {
            hasCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                hasCopied = false
            }
        }
    }
}
