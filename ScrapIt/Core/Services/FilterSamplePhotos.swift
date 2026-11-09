import CoreImage
import Foundation
import UIKit

/// Sample photos on the Choose Filter page (change 017): the user's original photos (Freepik, license
/// credit still [Open]), bundled small and filtered at runtime by `FilmFilterPipeline`, so they always
/// match the camera.
nonisolated enum FilterSamplePhotos {
    static let countPerFilter = 4

    static func assetNames(for filter: RollFilter) -> [String] {
        switch filter {
        case .cinematicBW400:
            ["FilterSampleCafeFriends", "FilterSampleBeerCheers", "FilterSamplePizzaCards", "FilterSampleCanyonRock"]
        case .colorPrint200:
            ["FilterSampleBeach", "FilterSampleCafeSelfie", "FilterSampleWaterfallSelfie", "FilterSampleCafeEating"]
        }
    }
}

/// Renders a filter's samples once (off the main thread) and keeps them.
nonisolated final class FilterSampleRenderer: @unchecked Sendable {
    static let shared = FilterSampleRenderer()

    private let lock = NSLock()
    private var cache: [RollFilter: [CGImage]] = [:]

    func samples(for filter: RollFilter) async -> [CGImage] {
        if let cached = lock.withLock({ cache[filter] }) { return cached }
        let look = filter.look
        let names = FilterSamplePhotos.assetNames(for: filter)
        let images = await Task.detached(priority: .userInitiated) {
            Self.render(names: names, look: look)
        }.value
        lock.withLock { cache[filter] = images }
        return images
    }

    static func render(names: [String], look: FilmLook) -> [CGImage] {
        let pipeline = FilmFilterPipeline()
        let context = RenderContext.ciContext
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return names.compactMap { name in
            guard let photo = UIImage(named: name), let input = CIImage(image: photo) else { return nil }
            let oriented = input.oriented(CGImagePropertyOrientation(photo.imageOrientation))
            let filtered = pipeline.apply(look, to: oriented)
            return context.createCGImage(filtered, from: filtered.extent, format: .RGBA8, colorSpace: colorSpace)
        }
    }
}

private extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
