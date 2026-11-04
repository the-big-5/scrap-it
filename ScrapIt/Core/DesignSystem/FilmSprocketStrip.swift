import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct FilmSprocketStrip: View {
    var body: some View {
        GeometryReader { geo in
            let holeCount = max(10, Int(geo.size.width / 8))
            ZStack {
                Rectangle()
                    .fill(Color.black)
                HStack(spacing: 3) {
                    ForEach(0..<holeCount, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(ScrapTheme.creamBackground)
                            .frame(width: 4, height: 3)
                    }
                }
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Step 2: Choose a Filter (Figma node 675:5759)
