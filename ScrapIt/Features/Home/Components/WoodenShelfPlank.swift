import SwiftData
import SwiftUI

struct WoodenShelfPlank: View {
    var body: some View {
        Image("ShelfPlank")
            .resizable()
            .scaledToFit()
            .frame(width: 308, height: 22)
            .shadow(color: .black.opacity(0.22), radius: 8, y: 5)
    }
}
