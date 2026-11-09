import SwiftUI

/// A filter canister with its film strip. The selected filter's strip shows its sample photos, rendered with
/// the camera pipeline (change 017, Figma 1187:8489); the other strip stays dark.
struct FilmCanisterFilterRow: View {
    let filter: RollFilter
    let isSelected: Bool
    let samples: [CGImage]
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                // Canister body on the left
                FilmCanisterBadge(filter: filter, isSelected: isSelected)
                    .padding(.leading, 30)
                    .zIndex(1)

                // Horizontal sprocketed film roll with sample carousel frames
                VStack(spacing: 0) {
                    FilmSprocketStrip()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(0..<FilterSamplePhotos.countPerFilter, id: \.self) { index in
                                ZStack {
                                    ScrapTheme.filmStripDark
                                    if isSelected, samples.indices.contains(index) {
                                        Image(decorative: samples[index], scale: 1)
                                            .resizable()
                                            .scaledToFill()
                                            .transition(.opacity)
                                    }
                                }
                                .frame(width: 96, height: 84)
                                .clipped()
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.black, lineWidth: 1.5)
                                )
                            }
                        }
                    }
                    .frame(height: 84)
                    .background(ScrapTheme.filmStripDark)

                    FilmSprocketStrip()
                }
                .offset(x: -6)
            }
            .scaleEffect(isSelected ? 1.0 : 0.97, anchor: .leading)
        }
        .buttonStyle(.plain)
    }
}
