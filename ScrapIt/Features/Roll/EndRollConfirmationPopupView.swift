import SwiftUI

/// Modal confirmation dialog presented to host upon tapping "End Roll" (Figma node 1517:25254).
struct EndRollConfirmationPopupView: View {
    let shotsRemaining: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var subtitleText: String {
        if shotsRemaining == 1 {
            return "You still have 1 shot left. Once you end the roll, you can’t take any more photos."
        } else {
            return "You still have \(shotsRemaining) shots left. Once you end the roll, you can’t take any more photos."
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Image("PopupEndRollCanister")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 86, height: 90)
                    .accessibilityHidden(true)

                Text("End this roll?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(red: 0x1E / 255, green: 0x1A / 255, blue: 0x1A / 255))

                Text(subtitleText)
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(Color(red: 0x5B / 255, green: 0x54 / 255, blue: 0x4C / 255))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(DSColor.Brand.primary.color)
                        .frame(width: 108, height: 52)
                        .background(DSColor.Paper.lightActive.color, in: RoundedRectangle(cornerRadius: 26))
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text("Yes")
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(DSColor.Kraft.light.color)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(DSColor.Brand.primary.color, in: RoundedRectangle(cornerRadius: 26))
                }
                .buttonStyle(.plain)
            }
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
