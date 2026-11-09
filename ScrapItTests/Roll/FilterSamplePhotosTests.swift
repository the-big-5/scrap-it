import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import ScrapIt

/// Change 017: sample photos on the Choose Filter page, rendered with the camera pipeline.
struct FilterSamplePhotosTests {
    @Test(arguments: RollFilter.allCases)
    func eachFilterHasFourBundledSamples(_ filter: RollFilter) {
        let names = FilterSamplePhotos.assetNames(for: filter)
        #expect(names.count == FilterSamplePhotos.countPerFilter)
        let rendered = FilterSampleRenderer.render(names: names, look: filter.look)
        #expect(rendered.count == FilterSamplePhotos.countPerFilter)
        #expect(rendered.allSatisfy { max($0.width, $0.height) == 720 })
    }

    @Test func filtersUseDifferentPhotos() {
        let bw = Set(FilterSamplePhotos.assetNames(for: .cinematicBW400))
        let digicam = Set(FilterSamplePhotos.assetNames(for: .colorPrint200))
        #expect(bw.isDisjoint(with: digicam))
    }

    @Test func blackAndWhiteSamplesAreGrayscale() throws {
        let name = try #require(FilterSamplePhotos.assetNames(for: .cinematicBW400).first)
        let image = try #require(FilterSampleRenderer.render(names: [name], look: .noir).first)
        let pixel = try #require(Self.centerPixel(of: image))
        #expect(abs(pixel.r - pixel.g) <= 2 && abs(pixel.g - pixel.b) <= 2)
    }

    @Test func digicamSamplesKeepColor() throws {
        let names = FilterSamplePhotos.assetNames(for: .colorPrint200)
        let images = FilterSampleRenderer.render(names: names, look: .digicam)
        let colorful = images.compactMap(Self.centerPixel(of:)).contains { abs($0.r - $0.b) > 10 }
        #expect(colorful)
    }

    @MainActor
    @Test func viewModelLoadsSamplesForEveryFilter() async throws {
        let container = try ModelContainerFactory.inMemory()
        let vm = RollFlowViewModel(modelContext: container.mainContext, sessionStore: SessionStore(modelContext: container.mainContext))
        await vm.loadFilterSamples()
        for filter in RollFilter.allCases {
            #expect(vm.filterSamples[filter]?.count == FilterSamplePhotos.countPerFilter)
        }
    }

    private static func centerPixel(of image: CGImage) -> (r: Int, g: Int, b: Int)? {
        var bytes = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: -CGFloat(image.width) / 2, y: -CGFloat(image.height) / 2,
                                       width: CGFloat(image.width), height: CGFloat(image.height)))
        return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
    }
}

private enum ModelContainerFactory {
    @MainActor
    static func inMemory() throws -> ModelContainer {
        try ModelContainer(
            for: ScrapIt.schema,
            // Unique name: the test host app already uses the "default" and "Rolls" stores.
            configurations: ModelConfiguration(UUID().uuidString, schema: ScrapIt.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }
}
