import SwiftData
import SwiftUI

struct ShelfBooksCluster: View {
    var scrapbooks: [Scrapbook]
    var onTapMemories: () -> Void

    var body: some View {
        Button(action: onTapMemories) {
            Image("ShelfBooks")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 136)
        }
        .buttonStyle(.plain)
    }
}
