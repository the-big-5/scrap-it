import SwiftUI

/// 100pt participant avatar with name and "(Host)" / "(You)" (Figma 768:1291).
/// Initials only for now; profile photos come with the Profile screen [Open].
struct RollAvatarView: View {
    let participant: RoomParticipant
    let isHost: Bool
    let isCurrentUser: Bool

    private static let ink = DSColor.Brand.primary.color

    /// Alternates the two Figma initial styles by participant [Draft]:
    /// surface with ink text ("F") and burgundy with paper text ("S").
    private var usesBurgundy: Bool {
        participant.userID.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 2 == 1
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(RollFlowViewModel.initials(for: participant.name))
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(usesBurgundy ? DSColor.Paper.light.color : Self.ink)
                .frame(width: 100, height: 100)
                .background(Circle().fill(usesBurgundy ? DSColor.Brand.tertiary.color : DSColor.Component.surface.color))
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
