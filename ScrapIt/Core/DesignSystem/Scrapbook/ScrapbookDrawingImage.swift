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
            // A drawing rendered ahead (`prerender`) shows at once, so swapping data doesn't flash (change 150).
            let shown = data.flatMap { $0.isEmpty ? nil : Self.cached($0, width: geometry.size.width) } ?? (data == nil ? nil : image)
            ZStack(alignment: .topLeading) {
                if case let (uiImage, rect)? = shown {
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
                if let cached = Self.cached(data, width: geometry.size.width) {
                    image = cached
                    return
                }
                let scale = max(geometry.size.height / ScrapbookPage.canvasSize.height * displayScale, 0.1)
                let canvas = ScrapbookPage.canvasSize(for: geometry.size)
                let width = geometry.size.width
                image = await Task.detached(priority: .userInitiated) {
                    let rendered = Self.lightImage(of: data, canvas: canvas, scale: scale)
                    if let rendered { Self.store(rendered, for: data, width: width) }
                    return rendered
                }.value
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Cache (change 150)

    private final class Rendered {
        let value: (UIImage, CGRect)
        init(_ value: (UIImage, CGRect)) { self.value = value }
    }

    nonisolated(unsafe) private static let cache: NSCache<NSString, Rendered> = {
        let cache = NSCache<NSString, Rendered>()
        cache.countLimit = 40
        return cache
    }()

    /// The whole drawing's content (not only its start) and the page width it was drawn for.
    nonisolated private static func key(_ data: Data, width: CGFloat) -> NSString {
        var hasher = Hasher()
        data.withUnsafeBytes { hasher.combine(bytes: $0) }
        return "\(data.count)-\(hasher.finalize())-\(Int(width))" as NSString
    }

    nonisolated private static func cached(_ data: Data, width: CGFloat) -> (UIImage, CGRect)? {
        cache.object(forKey: key(data, width: width))?.value
    }

    nonisolated private static func store(_ rendered: (UIImage, CGRect), for data: Data, width: CGFloat) {
        cache.setObject(Rendered(rendered), forKey: key(data, width: width))
    }

    /// Renders a drawing now, for a page of this size, so the next view showing it doesn't wait (selecting or
    /// moving a pencil drawing, change 150).
    nonisolated static func prerender(_ data: Data, pageSize: CGSize, displayScale: CGFloat) {
        guard !data.isEmpty, pageSize.width > 0, pageSize.height > 0, cached(data, width: pageSize.width) == nil else { return }
        let scale = max(pageSize.height / ScrapbookPage.canvasSize.height * displayScale, 0.1)
        if let rendered = lightImage(of: data, canvas: ScrapbookPage.canvasSize(for: pageSize), scale: scale) {
            store(rendered, for: data, width: pageSize.width)
        }
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
