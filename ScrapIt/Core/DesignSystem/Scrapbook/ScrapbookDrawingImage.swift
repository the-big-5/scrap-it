import PencilKit
import SwiftUI

/// A PencilKit drawing as a still image (covers, change 013; drawing layers that aren't being drawn, change 022).
/// The drawing lives in `ScrapbookPage.canvasSize` points and is scaled to fill the page. The image is rendered
/// once per drawing and size, off the main thread.
struct ScrapbookDrawingImage: View {
    let data: Data?
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task(id: "\(data?.hashValue ?? 0)-\(Int(geometry.size.width))") {
                guard let data, !data.isEmpty, geometry.size.width > 0 else {
                    image = nil
                    return
                }
                let scale = max(geometry.size.height / ScrapbookPage.canvasSize.height * displayScale, 0.1)
                let canvas = ScrapbookPage.canvasSize(for: geometry.size)
                image = await Task.detached(priority: .userInitiated) {
                    Self.lightImage(of: data, canvas: canvas, scale: scale)
                }.value
            }
        }
        .allowsHitTesting(false)
    }

    /// Always the light-mode ink colors, like the canvas (otherwise black ink turns white in dark mode; brief K5).
    nonisolated private static func lightImage(of data: Data, canvas: CGSize, scale: CGFloat) -> UIImage? {
        guard let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty else { return nil }
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: CGRect(origin: .zero, size: canvas), scale: scale)
        }
        return image
    }
}
