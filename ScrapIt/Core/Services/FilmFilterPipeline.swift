import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Metal
import UniformTypeIdentifiers

/// The look of a roll's filter, usable off the main actor (preview, photo and Live Photo queues).
nonisolated enum FilmLook: Sendable, Equatable {
    /// Cinematic 400 Pro 35 Black & White.
    case noir
    /// 200 Color Print (yellow canister): Digicam look, change 016.
    case digicam
}

extension RollFilter {
    var look: FilmLook {
        switch self {
        case .cinematicBW400: .noir
        case .colorPrint200: .digicam
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
    /// Digicam still photos are scaled to this long side before the look, so blur / sharpen match the preview.
    static let digicamPhotoLongSide: CGFloat = 2048

    private let noir = CIFilter.photoEffectNoir()

    // Digicam (change 016, camera POC): grade → soft lens blur → edge sharpen → vignette.
    private let grade = CIFilter.colorCubeWithColorSpace()
    private let blur = CIFilter.gaussianBlur()
    private let sharpen = CIFilter.sharpenLuminance()
    private let vignette = CIFilter.vignette()
    private let downscale = CIFilter.lanczosScaleTransform()

    init() {
        grade.cubeDimension = Float(DigicamGrade.dimension)
        grade.cubeData = DigicamGrade.cubeData
        grade.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        blur.radius = 0.6
        sharpen.sharpness = 0.4
        vignette.intensity = 0.5
        vignette.radius = 1.5
        downscale.aspectRatio = 1
    }

    /// `forFinalPhoto`: the still photo. Digicam photos are downscaled to 2048 px first; the preview and the
    /// Live Photo movie frames are filtered as they are.
    func apply(_ look: FilmLook, to image: CIImage, forFinalPhoto: Bool = false) -> CIImage {
        switch look {
        case .noir:
            noir.inputImage = image
            return noir.outputImage ?? image
        case .digicam:
            return digicam(forFinalPhoto ? downscaled(image) : image)
        }
    }

    private func digicam(_ input: CIImage) -> CIImage {
        let extent = input.extent
        grade.inputImage = input
        blur.inputImage = grade.outputImage?.clampedToExtent()
        sharpen.inputImage = blur.outputImage?.cropped(to: extent)
        vignette.inputImage = sharpen.outputImage
        return vignette.outputImage?.cropped(to: extent) ?? input
    }

    private func downscaled(_ image: CIImage) -> CIImage {
        let scale = Self.digicamPhotoLongSide / max(image.extent.width, image.extent.height)
        guard scale < 1 else { return image }
        downscale.inputImage = image
        downscale.scale = Float(scale)
        guard let output = downscale.outputImage else { return image }
        // Lanczos with a Float scale can round up a pixel (4032 → 2049); crop to the exact target size.
        let e = output.extent
        return output.cropped(to: CGRect(x: e.minX, y: e.minY,
                                         width: (image.extent.width * scale).rounded(.down),
                                         height: (image.extent.height * scale).rounded(.down)))
    }
}

nonisolated enum FilmPhotoEncoder {
    /// Apple MakerNote key that pairs a Live Photo still with its movie.
    static let contentIdentifierKey = "17"
    /// Max longest edge for stored/uploaded photos (change 014: keeps 4:3 sharpness without pixel bloat).
    static let maxDimension: CGFloat = 2048
    /// Sweet spot between visual fidelity and file size (change 014: ~60% size reduction over 0.90).
    static let defaultCompressionQuality: Double = 0.78

    /// Center-crops an image to 4:3 (landscape) or 3:4 (portrait) aspect ratio if it deviates.
    static func cropToStandardAspectRatio(_ image: CIImage, targetAspectRatio: CGFloat? = nil) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }
        let isPortrait = extent.height > extent.width
        let target = targetAspectRatio ?? (isPortrait ? (3.0 / 4.0) : (4.0 / 3.0))
        let current = extent.width / extent.height
        if abs(current - target) < 0.005 {
            return image
        }
        let cropRect: CGRect
        if current > target {
            let newWidth = (extent.height * target).rounded()
            let originX = (extent.origin.x + (extent.width - newWidth) / 2.0).rounded()
            cropRect = CGRect(x: originX, y: extent.origin.y, width: newWidth, height: extent.height)
        } else {
            let newHeight = (extent.width / target).rounded()
            let originY = (extent.origin.y + (extent.height - newHeight) / 2.0).rounded()
            cropRect = CGRect(x: extent.origin.x, y: originY, width: extent.width, height: newHeight)
        }
        let cropped = image.cropped(to: cropRect)
        return cropped.transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
    }

    /// Scales down large images proportionally so the longest edge does not exceed `maxDimension`.
    /// Preserves exact aspect ratio with zero cropping.
    static func downsampledImageIfNeeded(_ image: CIImage, maxDimension: CGFloat = maxDimension) -> CIImage {
        let extent = image.extent
        let maxSide = max(extent.width, extent.height)
        guard maxSide > maxDimension, maxSide > 0 else {
            return image
        }
        let scale = maxDimension / maxSide
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    /// Renders a filtered image to JPEG. `contentIdentifier` is set for Live Photos.
    static func jpegData(
        from image: CIImage,
        contentIdentifier: String? = nil,
        compressionQuality: Double = defaultCompressionQuality,
        context: CIContext = RenderContext.ciContext
    ) -> Data? {
        let croppedImage = cropToStandardAspectRatio(image)
        let targetImage = downsampledImageIfNeeded(croppedImage)
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        guard let cgImage = context.createCGImage(targetImage, from: targetImage.extent, format: .RGBA8, colorSpace: colorSpace) else {
            return nil
        }
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: compressionQuality]
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
