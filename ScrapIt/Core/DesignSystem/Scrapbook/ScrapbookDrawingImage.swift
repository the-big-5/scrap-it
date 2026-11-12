import PencilKit
import SwiftUI

/// A PencilKit drawing as a still image (covers, change 013; drawing layers that aren't being drawn, change 022).
/// The drawing lives in `ScrapbookPage.canvasSize` points and is scaled to fill the page. The image is rendered
/// once per drawing and size, off the main thread.
struct ScrapbookDrawingImage: View {
    let data: Data?
    @Environment(\.displayScale) private var displayScale
    /// The image and the part of the drawing space it covers: the page, plus strokes past its side edges, up to one
    /// page wide (a stroke drawn across the gutter of the two-page view, change 104).
    @State private var image: (UIImage, CGRect)?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if case let (uiImage, rect)? = image {
                    let points = geometry.size.width / ScrapbookPage.canvasSize(for: geometry.size).width
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: rect.width * points, height: rect.height * points)
                        .offset(x: rect.minX * points, y: rect.minY * points)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
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
    nonisolated private static func lightImage(of data: Data, canvas: CGSize, scale: CGFloat) -> (UIImage, CGRect)? {
        guard let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty else { return nil }
        let page = CGRect(origin: .zero, size: canvas)
        let reach = page.insetBy(dx: -canvas.width, dy: 0)
        let rect = page.union(drawing.bounds.intersection(reach))
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: scale)
        }
        return image.map { ($0, rect) }
    }
}
