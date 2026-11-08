import Foundation
import ImageIO
import UIKit

/// Loads scrapbook photos downsampled to their size on screen, cached in memory (change 013, POC).
/// Also reads a photo's aspect ratio from the image header without decoding it.
nonisolated final class ScrapbookImageLoader: @unchecked Sendable {
    static let shared = ScrapbookImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let aspectLock = NSLock()
    private var aspects: [UUID: CGFloat] = [:]

    init() {
        cache.countLimit = 200
    }

    /// A few size steps only, so cached images are reused.
    static func pixelSize(forLongSide pixels: CGFloat) -> Int {
        switch pixels {
        case ...400: 400
        case ...800: 800
        default: 1600
        }
    }

    func cachedImage(for id: UUID, pixelSize: Int) -> UIImage? {
        cache.object(forKey: Self.key(id, pixelSize))
    }

    func image(for id: UUID, data: Data, pixelSize: Int) async -> UIImage? {
        if let cached = cachedImage(for: id, pixelSize: pixelSize) { return cached }
        let image = await Task.detached(priority: .userInitiated) {
            Self.downsample(data, maxPixelSize: pixelSize)
        }.value
        if let image {
            cache.setObject(image, forKey: Self.key(id, pixelSize))
        }
        return image
    }

    /// Width / height with the EXIF orientation applied; `nil` if unreadable.
    func aspectRatio(for id: UUID, data: Data) -> CGFloat? {
        aspectLock.lock()
        defer { aspectLock.unlock() }
        if let known = aspects[id] { return known }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0 else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let ratio = (5...8).contains(orientation) ? height / width : width / height
        aspects[id] = ratio
        return ratio
    }

    private static func downsample(_ data: Data, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    private static func key(_ id: UUID, _ pixelSize: Int) -> NSString {
        "\(id.uuidString)-\(pixelSize)" as NSString
    }
}
