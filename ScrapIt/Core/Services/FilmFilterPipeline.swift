import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Metal
import UniformTypeIdentifiers

/// The look of a roll's filter, usable off the main actor (preview, photo and Live Photo queues).
nonisolated enum FilmLook: Sendable, Equatable {
    /// Cinematic 400 Pro 35 Black & White.
    case noir
    /// 200 Color Print.
    case chrome
}

extension RollFilter {
    var look: FilmLook {
        switch self {
        case .cinematicBW400: .noir
        case .colorPrint200: .chrome
        }
    }
}

/// One Metal-backed `CIContext` for preview, photo and Live Photo rendering.
nonisolated enum RenderContext {
    static let device: MTLDevice? = MTLCreateSystemDefaultDevice()

    static let ciContext: CIContext = {
        if let device {
            return CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        }
        return CIContext()
    }()
}

/// The roll filter as a Core Image chain. Preview, photo and Live Photo movie all use it, so photo = preview.
/// Filter objects are created once; per frame only the input changes.
/// Not thread-safe: use one instance per queue.
nonisolated final class FilmFilterPipeline {
    private let noir = CIFilter.photoEffectNoir()
    private let chrome = CIFilter.photoEffectChrome()

    func apply(_ look: FilmLook, to image: CIImage) -> CIImage {
        switch look {
        case .noir:
            noir.inputImage = image
            return noir.outputImage ?? image
        case .chrome:
            chrome.inputImage = image
            return chrome.outputImage ?? image
        }
    }
}

nonisolated enum FilmPhotoEncoder {
    /// Apple MakerNote key that pairs a Live Photo still with its movie.
    static let contentIdentifierKey = "17"

    /// Renders a filtered image to JPEG. `contentIdentifier` is set for Live Photos.
    static func jpegData(
        from image: CIImage,
        contentIdentifier: String? = nil,
        context: CIContext = RenderContext.ciContext
    ) -> Data? {
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        guard let cgImage = context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: colorSpace) else {
            return nil
        }
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
        if let contentIdentifier {
            properties[kCGImagePropertyMakerAppleDictionary] = [contentIdentifierKey: contentIdentifier]
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Reads the Live Photo content identifier back from a JPEG.
    static func contentIdentifier(in jpegData: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(jpegData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let maker = properties[kCGImagePropertyMakerAppleDictionary] as? [String: Any] else {
            return nil
        }
        // ImageIO stores this field with a fixed length (a UUID string); drop any padding.
        let value = (maker[contentIdentifierKey] as? String)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0."))
        return value?.isEmpty == false ? value : nil
    }
}
