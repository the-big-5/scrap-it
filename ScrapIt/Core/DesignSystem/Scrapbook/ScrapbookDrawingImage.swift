import PencilKit
import SwiftUI

/// A page's PencilKit drawing as a still image (covers, change 013). The drawing lives in
/// `ScrapbookPage.canvasSize` points and is scaled to fill the page.
struct ScrapbookDrawingImage: View {
    let data: Data?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            if let data, let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty {
                let scale = geometry.size.width / ScrapbookPage.canvasSize.width
                Image(uiImage: drawing.image(
                    from: CGRect(origin: .zero, size: ScrapbookPage.canvasSize),
                    scale: max(scale * displayScale, 0.1)
                ))
                .resizable()
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .allowsHitTesting(false)
    }
}
