import SwiftUI

enum ScrapTheme {
    static let creamBackground = Color(red: 0.965, green: 0.953, blue: 0.918)
    static let charcoal = Color(red: 0.133, green: 0.125, blue: 0.114)
    static let secondaryText = Color(red: 0.365, green: 0.349, blue: 0.318)
    static let cameraGreen = Color(red: 0.322, green: 0.447, blue: 0.282)
    static let cameraDarkGreen = Color(red: 0.255, green: 0.365, blue: 0.224)
    static let filmStripDark = Color(red: 0.180, green: 0.165, blue: 0.145)
    static let filmStripUnselected = Color(red: 0.325, green: 0.306, blue: 0.275)
    static let shelfWoodTop = Color(red: 0.353, green: 0.278, blue: 0.188)
    static let shelfWoodFront = Color(red: 0.247, green: 0.192, blue: 0.129)
    static let indicatorRed = Color(red: 0.780, green: 0.165, blue: 0.145)
    static let cameraGold = Color(red: 0.875, green: 0.753, blue: 0.365)
}

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

struct BackCircleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ScrapTheme.charcoal)
                .frame(width: 44, height: 44)
                .background(
                    ZStack {
                        Circle()
                            .fill(ScrapTheme.charcoal)
                            .offset(y: 3)
                        Circle()
                            .fill(Color.white)
                            .overlay(
                                Circle()
                                    .stroke(ScrapTheme.charcoal, lineWidth: 1.5)
                            )
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

struct RetroCameraIllustration: View {
    var scale: CGFloat = 1.0
    var showShadowPlate: Bool = true

    var body: some View {
        ZStack(alignment: .bottom) {
            if showShadowPlate {
                Ellipse()
                    .fill(Color.black.opacity(0.09))
                    .frame(width: 310 * scale, height: 64 * scale)
                    .offset(y: 12 * scale)
            }

            Image("HeroCamera")
                .resizable()
                .scaledToFit()
                .frame(width: 260 * scale, height: 180 * scale)
        }
    }
}
