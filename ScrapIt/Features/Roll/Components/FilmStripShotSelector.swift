import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

/// Film-strip shot count picker (change 081, Figma "Shot Picker" 1717:63264): the picked frame shows viewfinder
/// brackets and a larger number, so the choice reads without color; a light haptic on each pick.
struct FilmStripShotSelector: View {
    /// `nil` until the user picks (change 081).
    @Binding var selectedCount: Int?
    private let counts = RollFlowViewModel.availableShotCounts

    var body: some View {
        VStack(spacing: 0) {
            FilmSprocketStrip()

            HStack(spacing: 2) {
                ForEach(counts, id: \.self) { count in
                    let isSelected = (selectedCount == count)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedCount = count
                        }
                    } label: {
                        Text("\(count)")
                            .font(.system(size: isSelected ? 34 : 30, weight: .heavy))
                            .tracking(-0.5)
                            .foregroundStyle(isSelected ? Color.white : DSColor.Paper.dark.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(isSelected ? DSColor.Brand.primary.color : DSColor.Kraft.darker.color)
                            .overlay { if isSelected { brackets } }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(count) shots")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .background(Color.black)
            .sensoryFeedback(.selection, trigger: selectedCount)

            FilmSprocketStrip()
        }
    }

    /// Four 14 pt corner brackets, 8 pt in from each corner.
    private var brackets: some View {
        ZStack {
            bracket("ShotBracketTopLeft", .topLeading)
            bracket("ShotBracketTopRight", .topTrailing)
            bracket("ShotBracketBottomLeft", .bottomLeading)
            bracket("ShotBracketBottomRight", .bottomTrailing)
        }
        .padding(8)
        .allowsHitTesting(false)
    }

    private func bracket(_ name: String, _ alignment: Alignment) -> some View {
        Image(name)
            .resizable()
            .frame(width: 14, height: 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}
