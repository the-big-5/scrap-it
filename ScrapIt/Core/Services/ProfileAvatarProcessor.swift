import Foundation
import ImageIO
import UIKit

/// Downsamples and JPEG-compresses picked avatar photos for lightweight private CloudKit sync.
enum ProfileAvatarProcessor {
    static let maxPixelSize = 512
    static let compressionQuality: CGFloat = 0.8

    nonisolated static func process(
        _ rawData: Data,
        maxPixelSize: Int = maxPixelSize,
        compressionQuality: CGFloat = compressionQuality
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(rawData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: compressionQuality)
    }

    nonisolated static func thumbnail(
        from rawData: Data?,
        maxPixelSize: Int,
        compressionQuality: CGFloat
    ) -> Data? {
        guard let rawData else { return nil }
        return process(rawData, maxPixelSize: maxPixelSize, compressionQuality: compressionQuality)
    }
}
