import SwiftUI

struct OffsetPillButtonStyle: ButtonStyle {
    var backgroundColor: Color = DSColor.Paper.light.color
    var foregroundColor: Color = DSColor.Brand.primary.color
    var shadowOffset: CGFloat = 6
    var height: CGFloat = 52
    var fontSize: CGFloat = 20
    var fontWeight: Font.Weight = .heavy

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Capsule()
                .fill(DSColor.Brand.primary.color)
                .offset(y: shadowOffset)

            Capsule()
                .fill(backgroundColor)
                .overlay(
                    Capsule()
                        .stroke(DSColor.Brand.primary.color, lineWidth: 1.5)
                )
                .overlay(
                    configuration.label
                        .font(.system(size: fontSize, weight: fontWeight))
                        .foregroundStyle(foregroundColor)
                )
                .offset(y: configuration.isPressed ? 2 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .contentShape(Capsule())
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
