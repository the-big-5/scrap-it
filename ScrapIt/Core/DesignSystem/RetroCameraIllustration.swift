import SwiftUI

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
