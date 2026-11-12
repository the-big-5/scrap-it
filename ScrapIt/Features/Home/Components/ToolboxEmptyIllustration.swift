import SwiftUI

/// Craft collage illustration for the empty "Resume Editing" state (Figma 1537:25830).
struct ToolboxEmptyIllustration: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1537:25840: Spiral notebook ("buku atas 4 1")
            Image("ToolboxEmptyNotebook")
                .resizable()
                .frame(width: 101.095, height: 149.37)
                .rotationEffect(.degrees(-21.28))
                .position(x: 74.21, y: 112.95)

            // 1537:25841: Green pencil ("ijo 4")
            Image("ToolboxEmptyPencil")
                .resizable()
                .frame(width: 42.054, height: 138.342)
                .rotationEffect(.degrees(35.61))
                .position(x: 167.63, y: 160.52)

            // 1537:25842: Yellow ruler ("ijo 2 1")
            Image("ToolboxEmptyRuler")
                .resizable()
                .frame(width: 20.476, height: 77.863)
                .rotationEffect(.degrees(-56.79))
                .position(x: 49.35, y: 175.62)

            // 1537:25843: Blue-handle scissors ("gunting 1")
            Image("ToolboxEmptyScissors")
                .resizable()
                .frame(width: 44.938, height: 110.381)
                .rotationEffect(.degrees(-103.03))
                .position(x: 137.76, y: 126.02)

            // 1537:25844: Orange starburst ("st b 2")
            Image("ToolboxEmptyStarburst")
                .resizable()
                .frame(width: 76.812, height: 122.85)
                .rotationEffect(.degrees(19.31))
                .position(x: 151.44, y: 70.67)

            // 1537:25845: Stacked photo cards ("Asset / Foto")
            ZStack {
                Image("ToolboxEmptyPhotoBack")
                    .resizable()
                    .frame(width: 33.41, height: 44.08)
                    .rotationEffect(.degrees(8.58))
                    .offset(x: -1.3, y: -1.0)

                Image("ToolboxEmptyPhotoFront")
                    .resizable()
                    .frame(width: 38.55, height: 44.95)
                    .rotationEffect(.degrees(-5.72))
                    .offset(x: -1.5, y: 1.0)
            }
            .frame(width: 61.024, height: 58.136)
            .rotationEffect(.degrees(7.95))
            .position(x: 112.08, y: 179.42)
        }
        .frame(width: 225, height: 229)
        .accessibilityHidden(true)
    }
}
