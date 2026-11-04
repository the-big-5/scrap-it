import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ScrapDataImageView: View {
    let data: Data

    var body: some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            placeholder
        }
        #else
        placeholder
        #endif
    }

    private var placeholder: some View {
        ZStack {
            ScrapTheme.filmStripDark
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
