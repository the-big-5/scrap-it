import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct FilmStripShotSelector: View {
    /// `nil` until the user picks (change 081).
    @Binding var selectedCount: Int?
    private let counts = RollFlowViewModel.availableShotCounts

    var body: some View {
        VStack(spacing: 0) {
            FilmSprocketStrip()

            HStack(spacing: 0) {
                ForEach(counts, id: \.self) { count in
                    let isSelected = (selectedCount == count)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedCount = count
                        }
                    } label: {
                        Text("\(count)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 82)
                            .background(
                                isSelected
                                    ? ScrapTheme.filmStripDark
                                    : ScrapTheme.filmStripUnselected
                            )
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            FilmSprocketStrip()
        }
    }
}
