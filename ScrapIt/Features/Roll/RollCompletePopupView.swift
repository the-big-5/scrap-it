import SwiftUI

/// Modal completion dialog presented when a roll completes or ends (Figma node 1512:26505).
struct RollCompletePopupView: View {
    let isEndedEarly: Bool
    let onReveal: () -> Void

    private var subtitleText: String {
        if isEndedEarly {
            return "The roll was ended early. Your memories are ready to be revealed."
        } else {
            return "You’ve captured every shot! Your memories are ready to be revealed."
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Image("PopupRollCompleteFilm")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 63, height: 133)
                    .accessibilityHidden(true)

                Text("Roll Complete!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(red: 0x1E / 255, green: 0x1A / 255, blue: 0x1A / 255))

                Text(subtitleText)
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(Color(red: 0x5B / 255, green: 0x54 / 255, blue: 0x4C / 255))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onReveal) {
                Text("Reveal Photos")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(DSColor.Kraft.light.color)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(DSColor.Brand.primary.color, in: RoundedRectangle(cornerRadius: 26))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
        .padding(.bottom, 18)
        .padding(.horizontal, 22)
        .frame(width: 337)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(DSColor.Paper.normal.color)
                .shadow(color: Color.black.opacity(0.28), radius: 12, x: 0, y: 12)
        )
        .overlay(alignment: .top) {
            Image("PopupWashiTape")
                .resizable()
                .frame(width: 96, height: 28)
                .rotationEffect(.degrees(-4))
                .offset(x: 0.86, y: -14)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }
}
