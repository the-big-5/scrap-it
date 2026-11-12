import SwiftUI

/// A filter canister with its film strip of sample photos, rendered with the camera pipeline (change 017).
/// Both strips show their photos; the picked film's photos run by themselves like a carousel and its canister
/// grows (change 081, Figma 1571:48191).
struct FilmCanisterFilterRow: View {
    let filter: RollFilter
    let isSelected: Bool
    let samples: [CGImage]
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let frameSize = CGSize(width: 96, height: 84)
    private static let spacing: CGFloat = 2
    /// Carousel speed, points per second.
    private static let speed: CGFloat = 24

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                FilmCanisterBadge(filter: filter, isSelected: isSelected)
                    .scaleEffect(isSelected ? 1.1 : 1)
                    .padding(.leading, 30)
                    .zIndex(1)

                VStack(spacing: 0) {
                    FilmSprocketStrip()
                    // The strip takes the width it's given; the photos (two copies while looping) are cut at its
                    // edge instead of widening the row past the screen.
                    Color.clear
                        .frame(height: Self.frameSize.height)
                        .overlay(alignment: .leading) { photos }
                        .clipped()
                        .background(ScrapTheme.filmStripDark)
                    FilmSprocketStrip()
                }
                .offset(x: -6)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3), value: isSelected)
    }

    /// The picked strip loops its photos (two copies side by side, shifted by one copy's width); the other stays put.
    @ViewBuilder
    private var photos: some View {
        if isSelected && !reduceMotion {
            TimelineView(.animation) { context in
                let loopWidth = CGFloat(FilterSamplePhotos.countPerFilter) * (Self.frameSize.width + Self.spacing)
                let shift = (CGFloat(context.date.timeIntervalSinceReferenceDate) * Self.speed)
                    .truncatingRemainder(dividingBy: loopWidth)
                HStack(spacing: Self.spacing) {
                    frames
                    frames
                }
                .offset(x: -shift)
            }
        } else {
            HStack(spacing: Self.spacing) { frames }
        }
    }

    @ViewBuilder
    private var frames: some View {
        ForEach(0..<FilterSamplePhotos.countPerFilter, id: \.self) { index in
            ZStack {
                ScrapTheme.filmStripDark
                if samples.indices.contains(index) {
                    Image(decorative: samples[index], scale: 1)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .frame(width: Self.frameSize.width, height: Self.frameSize.height)
            .clipped()
            .overlay(
                Rectangle()
                    .stroke(Color.black, lineWidth: 1.5)
            )
        }
    }
}
