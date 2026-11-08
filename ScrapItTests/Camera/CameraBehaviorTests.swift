import AVFoundation
import CoreImage
import Foundation
import ImageIO
import SwiftData
import Testing
import UIKit
@testable import ScrapIt

/// Change 008: zoom wheel, physical buttons, Camera Adjustments pop-up, orientation, filter, Live Photo.
@MainActor
struct CameraBehaviorTests {
    private static func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: UserProfile.self, Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
            configurations: ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return container.mainContext
    }
    /// Triple-camera-like phone: lenses 0.5×, 1×, 4×; device max 270 (135×) capped at 4×.
    static let tripleCamera = ZoomCapabilities.make(
        hasUltraWide: true,
        switchOverFactors: [2.0, 8.0],
        secondaryNativeFactors: [],
        minDeviceFactor: 1.0,
        maxDeviceFactor: 270.0
    )

    private func approx(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.0001 }

    // MARK: - Zoom wheel

    @Test func dragLeftZoomsIn() {
        var model = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 1)

        let update = model.drag(by: -16, velocity: 50)

        #expect(approx(model.zoom, 1.1))
        #expect(update.steps == 1)
    }

    @Test func dragRightZoomsOut() {
        var model = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 2)

        _ = model.drag(by: 16, velocity: 50)

        #expect(model.zoom < 2)
    }

    @Test func scaleIsLogarithmic() {
        var model = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 1)
        let at1 = model.travel
        model.sync(to: 2)
        let at2 = model.travel
        model.sync(to: 4)
        let at4 = model.travel

        #expect(abs((at2 - at1) - (at4 - at2)) < 0.0001)
        #expect(abs((at2 - at1) - ZoomWheelModel.pointsPerDoubling) < 0.0001)
    }

    @Test func fastDragCoversMoreSteps() {
        var slow = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 1.5)
        var fast = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 1.5)

        _ = slow.drag(by: -20, velocity: 60)
        _ = fast.drag(by: -20, velocity: 1500)

        #expect(fast.zoom > slow.zoom)
        #expect(ZoomWheelModel.gain(forSpeed: 60) == 1)
        #expect(ZoomWheelModel.gain(forSpeed: 100_000) == ZoomWheelModel.maxGain)
    }

    @Test func slowDragStopsAtLensThenNeedsExtraDrag() {
        var model = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 1.5)

        let hit = model.drag(by: 80, velocity: 50)
        #expect(hit.hitLens)
        #expect(approx(model.zoom, 1.0))

        _ = model.drag(by: 5, velocity: 50)
        #expect(approx(model.zoom, 1.0), "Detent holds")

        _ = model.drag(by: 20, velocity: 50)
        #expect(approx(model.zoom, 0.9))
    }

    @Test func fastDragPassesLensWithoutStopping() {
        var model = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 1.5)

        let update = model.drag(by: 30, velocity: 1500)

        #expect(update.hitLens)
        #expect(model.zoom < 1.0)
    }

    @Test func endstopsClampAndThudOnce() {
        var model = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 0.5)

        let first = model.drag(by: 50, velocity: 50)
        let second = model.drag(by: 10, velocity: 50)
        #expect(first.hitEndstop)
        #expect(!second.hitEndstop)
        #expect(approx(model.zoom, 0.5))

        _ = model.drag(by: -5_000, velocity: 100_000)
        #expect(approx(model.zoom, 4), "Max is 4x")
    }

    @Test func zoomAlwaysOnTenths() {
        var model = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 1)
        for _ in 0..<40 {
            _ = model.drag(by: -3.7, velocity: 80)
            let tenths = model.zoom * 10
            #expect(abs(tenths - tenths.rounded()) < 0.0001)
        }
    }

    @Test func ribsMoveWithTheFinger() {
        var model = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 1)
        let before = model.ribOffset(spacing: 16)

        _ = model.drag(by: -5, velocity: 50)

        #expect(model.ribOffset(spacing: 16) < before, "Finger moves left, ribs move left")
    }

    @Test func tapJumpsToNextLens() {
        let model = ZoomWheelModel(capabilities: Self.tripleCamera, zoom: 1)

        #expect(model.nextLens(zoomingIn: true) == 4)
        #expect(model.nextLens(zoomingIn: false) == 0.5)
    }

    @Test func frontCameraIsNotZoomable() {
        let model = ZoomWheelModel(capabilities: .none, zoom: 1)
        #expect(!model.isZoomable)
    }

    // MARK: - Physical buttons

    @Test func primaryButtonCapturesWithCameraControl() {
        #expect(PrimaryButtonAction.resolve(hasCameraControl: true) == .capture)
    }

    @Test func primaryButtonFlipsWithoutCameraControl() {
        #expect(PrimaryButtonAction.resolve(hasCameraControl: false) == .flipCamera)
    }

    @Test func flashCyclesOffOnAuto() {
        let camera = CameraController()
        camera.flashChoice = .off
        camera.handleSecondaryButton()
        #expect(camera.flashChoice == .on)
        camera.handleSecondaryButton()
        #expect(camera.flashChoice == .auto)
        camera.handleSecondaryButton()
        #expect(camera.flashChoice == .off)
    }

    // MARK: - Camera Adjustments pop-up

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "CameraBehaviorTests.\(UUID().uuidString)")!
    }

    @Test func promptShowsOncePerLaunch() {
        var prompt = CameraAdjustmentsPrompt(defaults: freshDefaults())

        let first = prompt.shouldShow(hasCameraControl: true)
        let second = prompt.shouldShow(hasCameraControl: true)
        #expect(first)
        #expect(!second)
    }

    @Test func promptNeverShowsWithoutCameraControl() {
        var prompt = CameraAdjustmentsPrompt(defaults: freshDefaults())
        let shows = prompt.shouldShow(hasCameraControl: false)
        #expect(!shows)
    }

    @Test func laterShowsAgainNextLaunch() {
        let defaults = freshDefaults()
        var firstLaunch = CameraAdjustmentsPrompt(defaults: defaults)
        _ = firstLaunch.shouldShow(hasCameraControl: true)

        var nextLaunch = CameraAdjustmentsPrompt(defaults: defaults)
        let shows = nextLaunch.shouldShow(hasCameraControl: true)
        #expect(shows)
    }

    @Test func alreadyOnOrDetectedStopsThePrompt() {
        let defaults = freshDefaults()
        CameraAdjustmentsPrompt(defaults: defaults).confirm()

        var nextLaunch = CameraAdjustmentsPrompt(defaults: defaults)
        let shows = nextLaunch.shouldShow(hasCameraControl: true)
        #expect(!shows)
    }

    @Test func dontRemindMeStopsThePrompt() {
        let defaults = freshDefaults()
        CameraAdjustmentsPrompt(defaults: defaults).dismissForever()

        var nextLaunch = CameraAdjustmentsPrompt(defaults: defaults)
        let shows = nextLaunch.shouldShow(hasCameraControl: true)
        #expect(!shows)
    }

    // MARK: - Orientation

    @Test func captureSessionIsLandscapeOthersPortrait() {
        #expect(OrientationLock.mask(isCaptureSessionVisible: true) == .landscape)
        #expect(OrientationLock.mask(isCaptureSessionVisible: false) == .portrait)
    }

    // MARK: - Shots counter (taken / total)

    @Test func shotsCounterCountsUp() {
        let context = Self.makeInMemoryContext()
        let store = SessionStore(modelContext: context)
        let session = CaptureSession(
            name: "Trip",
            hostUserID: "apple-123",
            participantIDs: ["apple-123"],
            participantNames: ["Ana"],
            rollSize: 36
        )
        store.activeSession = session
        let viewModel = RollFlowViewModel(modelContext: context, sessionStore: store)

        #expect(viewModel.takenShotsText == "00")
        #expect(viewModel.totalShotsText == "/36")

        session.slotsUsed = 9
        #expect(viewModel.takenShotsText == "09")

        session.slotsUsed = 36
        #expect(viewModel.takenShotsText == "36")
    }

    @Test func shotsCounterStartsAtZeroWithoutSession() {
        let context = Self.makeInMemoryContext()
        let store = SessionStore(modelContext: context)
        let viewModel = RollFlowViewModel(modelContext: context, sessionStore: store)
        #expect(viewModel.takenShotsText == "00")
    }

    // MARK: - Filter pipeline

    private static func pixel(of image: CIImage) -> (r: Int, g: Int, b: Int) {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
    }

    private static let orange = CIImage(color: CIColor(red: 0.9, green: 0.5, blue: 0.1))
        .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))

    @Test func blackAndWhiteFilterIsGrayscale() {
        let output = FilmFilterPipeline().apply(.noir, to: Self.orange)
        let p = Self.pixel(of: output)

        #expect(abs(p.r - p.g) <= 1 && abs(p.g - p.b) <= 1)
    }

    @Test func colorFilterKeepsColor() {
        let output = FilmFilterPipeline().apply(.chrome, to: Self.orange)
        let p = Self.pixel(of: output)

        #expect(p.r > p.b + 20)
    }

    @Test func previewAndPhotoUseTheSameResult() {
        for look in [FilmLook.noir, .chrome] {
            let preview = Self.pixel(of: FilmFilterPipeline().apply(look, to: Self.orange))
            let photo = Self.pixel(of: FilmFilterPipeline().apply(look, to: Self.orange))
            #expect(preview == photo)
        }
    }

    @Test func rollFiltersMapToLooks() {
        #expect(RollFilter.cinematicBW400.look == .noir)
        #expect(RollFilter.colorPrint200.look == .chrome)
    }

    // MARK: - Live Photo pairing

    @Test func stillCarriesContentIdentifier() throws {
        // The app always uses a UUID string (ImageIO stores this field at UUID length).
        let identifier = UUID().uuidString
        let data = try #require(FilmPhotoEncoder.jpegData(from: Self.orange, contentIdentifier: identifier))
        #expect(FilmPhotoEncoder.contentIdentifier(in: data) == identifier)
    }

    @Test func stillWithoutLiveHasNoIdentifier() throws {
        let data = try #require(FilmPhotoEncoder.jpegData(from: Self.orange))
        #expect(FilmPhotoEncoder.contentIdentifier(in: data) == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func filteredMovieCarriesSameContentIdentifier() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "LivePhotoTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let identifier = UUID().uuidString
        let source = folder.appending(path: "source.mov")
        let output = folder.appending(path: "output.mov")
        try await Self.writeTestMovie(to: source, frames: 15)

        try await LivePhotoMovieWriter.write(
            from: source,
            to: output,
            look: .noir,
            contentIdentifier: identifier,
            photoDisplayTime: CMTime(value: 7, timescale: 30)
        )

        #expect(await LivePhotoMovieWriter.contentIdentifier(of: output) == identifier)
    }

    /// Small solid-color H.264 movie as a stand-in for a camera Live Photo movie.
    private static func writeTestMovie(to url: URL, frames: Int) async throws {
        let width = 64, height = 48
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        let context = CIContext()
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            var buffer: CVPixelBuffer?
            if let pool = adaptor.pixelBufferPool {
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            }
            let pixelBuffer = try #require(buffer)
            context.render(orange, to: pixelBuffer)
            adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed)
    }

    // MARK: - Photo downsampling & compression optimization (change 014)

    @Test func photoEncoderDownscalesLargeImagePreservingAspectRatio() throws {
        let largeImage = CIImage(color: CIColor(red: 0.2, green: 0.6, blue: 0.9))
            .cropped(to: CGRect(x: 0, y: 0, width: 4032, height: 3024))
        let identifier = UUID().uuidString
        let data = try #require(FilmPhotoEncoder.jpegData(from: largeImage, contentIdentifier: identifier))

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int else {
            Issue.record("Failed to read image properties from encoded JPEG")
            return
        }

        #expect(pixelWidth == 2048)
        #expect(pixelHeight == 1536)
        #expect(FilmPhotoEncoder.contentIdentifier(in: data) == identifier)
        #expect(data.count < 1_000_000)
    }

    @Test func photoEncoderLeavesSmallImageUndownscaled() throws {
        let smallImage = CIImage(color: CIColor(red: 0.2, green: 0.6, blue: 0.9))
            .cropped(to: CGRect(x: 0, y: 0, width: 800, height: 600))
        let data = try #require(FilmPhotoEncoder.jpegData(from: smallImage))

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int else {
            Issue.record("Failed to read image properties from encoded JPEG")
            return
        }

        #expect(pixelWidth == 800)
        #expect(pixelHeight == 600)
    }

    @Test func movieWriterConstrainsDimensionsTo1440pStandard() {
        let rawSize = CGSize(width: 1920, height: 1440)
        let (width, height, scaleX, scaleY) = LivePhotoMovieWriter.constrainedDimensions(from: rawSize)
        #expect(width == 1440)
        #expect(height == 1080)
        #expect(width % 2 == 0)
        #expect(height % 2 == 0)
        #expect(abs(scaleX - 0.75) < 0.01)
        #expect(abs(scaleY - 0.75) < 0.01)

        let smallSize = CGSize(width: 640, height: 480)
        let (smallW, smallH, smallScaleX, smallScaleY) = LivePhotoMovieWriter.constrainedDimensions(from: smallSize)
        #expect(smallW == 640)
        #expect(smallH == 480)
        #expect(smallScaleX == 1.0)
        #expect(smallScaleY == 1.0)
    }
}
