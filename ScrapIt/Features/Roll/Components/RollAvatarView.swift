import SwiftUI
import UIKit

/// 100pt participant avatar with name and "(Host)" / "(You)" (Figma 768:1291).
/// Shows the shared profile photo when available, falling back to initials.
struct RollAvatarView: View {
    let participant: RoomParticipant
    let isHost: Bool
    let isCurrentUser: Bool
    private let resolvedAvatarData: Data?

    private static let ink = DSColor.Brand.primary.color

    init(participant: RoomParticipant, isHost: Bool, isCurrentUser: Bool) {
        self.participant = participant
        self.isHost = isHost
        self.isCurrentUser = isCurrentUser
        self.resolvedAvatarData = participant.avatarData
    }

    init(participant: RoomParticipant, isHost: Bool, isCurrentUser: Bool, avatarData: Data?) {
        self.participant = participant
        self.isHost = isHost
        self.isCurrentUser = isCurrentUser
        self.resolvedAvatarData = avatarData
    }

    /// Alternates the two Figma initial styles by participant [Draft]:
    /// surface with ink text ("F") and burgundy with paper text ("S").
    private var usesBurgundy: Bool {
        participant.userID.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 2 == 1
    }

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let resolvedAvatarData, let image = UIImage(data: resolvedAvatarData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(RollFlowViewModel.initials(for: participant.name))
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(usesBurgundy ? DSColor.Paper.light.color : Self.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(usesBurgundy ? DSColor.Brand.tertiary.color : DSColor.Component.surface.color)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(Self.ink, lineWidth: 1))

            VStack(spacing: 0) {
                Text(participant.name)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                if isHost {
                    Text("(Host)").font(.system(size: 15))
                } else if isCurrentUser {
                    Text("(You)").font(.system(size: 15))
                }
            }
            .foregroundStyle(Self.ink)
            .multilineTextAlignment(.center)
        }
        .frame(width: 100)
        .accessibilityElement(children: .combine)
    }
}
