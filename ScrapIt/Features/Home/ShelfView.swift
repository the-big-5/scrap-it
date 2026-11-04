import SwiftData
import SwiftUI

struct ShelfView: View {
    var scrapbooks: [Scrapbook]
    var onTapCamera: () -> Void
    var onTapScrapbook: (Scrapbook) -> Void

    var body: some View {
        ZStack {
            // Warm lamp light cone
            LampLightConeShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.91, blue: 0.68).opacity(0.50),
                            Color(red: 0.99, green: 0.93, blue: 0.76).opacity(0.22),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 380, height: 600)
                .offset(y: -10)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Hanging Pendant Lamp (Figma node 663:4866)
                HangingLampIllustration()
                    .padding(.bottom, 28)

                // Top Shelf: Camera (interactive), Potted Plant, Stickers Toolbox
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 10) {
                        Button(action: onTapCamera) {
                            Image("ShelfCamera")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 83, height: 57)
                                .accessibilityLabel("Camera Roll")
                        }
                        .buttonStyle(.plain)

                        PottedPlantIllustration()

                        StickerCaddyIllustration()
                    }
                    .padding(.horizontal, 26)

                    WoodenShelfPlank()
                        .offset(y: -4)
                }
                .padding(.bottom, 48)

                // Bottom Shelf: Cat Figurine, Standing Books ("memories"), Film Canisters
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        CatFigurineIllustration()
                            .padding(.trailing, 2)

                        ShelfBooksCluster(
                            scrapbooks: scrapbooks,
                            onTapMemories: {
                                if let latest = scrapbooks.first {
                                    onTapScrapbook(latest)
                                }
                            }
                        )

                        Spacer(minLength: 16)

                        ShelfFilmCanistersCluster()
                    }
                    .padding(.horizontal, 42)

                    WoodenShelfPlank()
                        .offset(y: -4)
                }

                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}
