import SwiftUI

/// Cream paper background with grain texture matching ScrapIt design foundations (change 110).
struct CameraIntroPaperBackground: View {
    var opacity: Double = 1.0

    var body: some View {
        ZStack {
            // Warm cream base (#F4EFE6)
            Color(red: 244 / 255, green: 239 / 255, blue: 230 / 255)

            // Radial vignette to give physical depth
            RadialGradient(
                colors: [
                    Color(red: 251 / 255, green: 247 / 255, blue: 239 / 255),
                    Color(red: 244 / 255, green: 239 / 255, blue: 230 / 255),
                    Color(red: 228 / 255, green: 214 / 255, blue: 191 / 255)
                ],
                center: .init(x: 0.5, y: 0.44),
                startRadius: 40,
                endRadius: 520
            )
            .opacity(0.85)

            // Bottom warm shadow gradient
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color(red: 228 / 255, green: 214 / 255, blue: 191 / 255).opacity(0),
                        Color(red: 214 / 255, green: 196 / 255, blue: 168 / 255).opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 320)
            }
        }
        .opacity(opacity)
        .ignoresSafeArea()
    }
}

/// "Tap anywhere to skip" label matching mockup caption styling (change 110).
struct CameraIntroSkipPromptView: View {
    var opacity: Double = 1.0

    var body: some View {
        VStack {
            Spacer()
            Text("Tap anywhere to skip")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 138 / 255, green: 128 / 255, blue: 117 / 255))
                .tracking(0.2)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.55))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                )
                .padding(.bottom, 56)
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}
