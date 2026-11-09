import CoreImage
import Foundation
import Testing
@testable import ScrapIt

/// Change 016: Digicam look for the yellow 200 Color Print canister.
struct DigicamFilterTests {
    @Test func cubeHas33CubedRGBAEntries() {
        #expect(DigicamGrade.cubeData.count == 33 * 33 * 33 * 4 * MemoryLayout<Float>.size)
    }

    @Test func blacksAreLiftedAndWhitesAreCream() {
        let black = DigicamGrade.apply(0, 0, 0)
        let white = DigicamGrade.apply(1, 1, 1)

        #expect(black.r >= DigicamGrade.lift - 1e-9 && black.g >= DigicamGrade.lift - 1e-9 && black.b >= DigicamGrade.lift - 1e-9)
        #expect(white.r <= DigicamGrade.cap + 1e-9 && white.g <= DigicamGrade.cap + 1e-9)
        // Cream, never pure white: blue stays below red.
        #expect(white.b < white.r)
    }

    @Test func gradeIsDarkerAndWarmer() {
        let gray = DigicamGrade.apply(0.5, 0.5, 0.5)
        let luma = 0.2126 * gray.r + 0.7152 * gray.g + 0.0722 * gray.b
        #expect(luma < 0.5)
        #expect(gray.b < gray.r)
    }

    @Test func warmthIsStrongestInTheShadows() {
        let dark = DigicamGrade.apply(0.2, 0.2, 0.2)
        let light = DigicamGrade.apply(0.8, 0.8, 0.8)
        #expect(dark.b / dark.r < light.b / light.r)
    }

    @Test func previewKeepsTheImageSize() {
        let image = CIImage(color: CIColor(red: 0.5, green: 0.4, blue: 0.3)).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))
        let output = FilmFilterPipeline().apply(.digicam, to: image)
        #expect(output.extent == image.extent)
    }

    @Test func digicamPhotoIsScaledTo2048BeforeTheLook() {
        let photo = CIImage(color: CIColor(red: 0.5, green: 0.4, blue: 0.3)).cropped(to: CGRect(x: 0, y: 0, width: 4032, height: 3024))
        let output = FilmFilterPipeline().apply(.digicam, to: photo, forFinalPhoto: true)
        #expect(max(output.extent.width, output.extent.height) == FilmFilterPipeline.digicamPhotoLongSide)
        #expect(output.extent.width <= 2048 && output.extent.height <= 1536)
    }

    @Test func blackAndWhitePhotoIsNotScaledByThePipeline() {
        let photo = CIImage(color: CIColor(red: 0.5, green: 0.4, blue: 0.3)).cropped(to: CGRect(x: 0, y: 0, width: 4032, height: 3024))
        let output = FilmFilterPipeline().apply(.noir, to: photo, forFinalPhoto: true)
        #expect(output.extent == photo.extent)
    }
}
