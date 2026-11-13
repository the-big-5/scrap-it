import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct FilmSprocketStrip: View {
    var body: some View {
        GeometryReader { geo in
            let holeWidth: CGFloat = 4
            let spacing: CGFloat = 3
            let holeCount = max(10, Int(ceil((geo.size.width + spacing) / (holeWidth + spacing))))
            ZStack {
                Rectangle()
                    .fill(Color.black)
                HStack(spacing: spacing) {
                    ForEach(0..<holeCount, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(ScrapTheme.creamBackground)
                            .frame(width: holeWidth, height: 3)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .frame(height: 6)
    }
}

// MARK: - Step 2: Choose a Filter (Figma node 675:5759)
