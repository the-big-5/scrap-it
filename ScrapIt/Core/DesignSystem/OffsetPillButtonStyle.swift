import SwiftUI

struct OffsetPillButtonStyle: ButtonStyle {
    var backgroundColor: Color = .white
    var foregroundColor: Color = ScrapTheme.charcoal
    var shadowOffset: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    Capsule()
                        .fill(ScrapTheme.charcoal)
                        .offset(y: configuration.isPressed ? 2 : shadowOffset)
                    Capsule()
                        .fill(backgroundColor)
                        .overlay(
                            Capsule()
                                .stroke(ScrapTheme.charcoal, lineWidth: 1.5)
                        )
                        .offset(y: configuration.isPressed ? 2 : 0)
                }
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
