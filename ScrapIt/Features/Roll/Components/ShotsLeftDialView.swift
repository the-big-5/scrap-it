import SwiftUI

/// Circular analog shots-left dial element (change 041) matching Figma nodes 1302:47951 / 1300:33812.
/// Displays remaining shots count as a mechanical rolling number drum inside the Figma analog dial housing.
struct ShotsLeftDialView: View {
    let shotsRemaining: Int

    private static let creamText = Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255)

    var body: some View {
        ZStack {
            // Outer Dial Housing from Figma (with drop shadows and embossed rim)
            Image("CameraDialOuter")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 118, height: 118)

            // Inner Recessed Drum (Figma 1302:47954, 55.865pt diameter)
            ZStack {
                Image("CameraDialInner")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)

                // Rotating analog drum number display
                VStack(spacing: 4) {
                    Text("\(shotsRemaining + 1)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Self.creamText.opacity(0.35))

                    Text("\(shotsRemaining)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Self.creamText)

                    Text("\(max(0, shotsRemaining - 1))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Self.creamText.opacity(0.35))
                }
                .animation(.easeInOut(duration: 0.25), value: shotsRemaining)
                .frame(width: 50, height: 50)
                .clipped()
            }
            .frame(width: 56, height: 56)
        }
        .frame(width: 83, height: 83)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shotsRemaining) shots left")
    }
}
