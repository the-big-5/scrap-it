import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct FilmCanisterBadge: View {
    let filter: RollFilter
    let isSelected: Bool

    var body: some View {
        Image(filter == .cinematicBW400 ? "FilterCanisterBW" : "FilterCanisterColor")
            .resizable()
            .scaledToFit()
            .frame(width: 89, height: 142)
            .scaleEffect(isSelected ? 1.03 : 0.96)
    }
}

// MARK: - Step 3: Share Room / Lobby (Figma node 675:5798)
