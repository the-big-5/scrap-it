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
    /// Dual-wide camera phone (change 060): lenses 0.5×, 1×, 2×; device max 270 capped at 4× without telephoto.
    static let dualWideCamera = ZoomCapabilities.make(
        hasUltraWide: true,
        switchOverFactors: [2.0],
        secondaryNativeFactors: [2.0],
        minDeviceFactor: 1.0,
        maxDeviceFactor: 270.0
    )

    private func approx(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.0001 }

    // MARK: - Zoom wheel (Discrete stepping & sensor allocation)

    @Test func discreteZoomStopStepIndexMapping() {
        let stopAtOne = ZoomStop.from(factor: 1.0)
        #expect(stopAtOne.stepIndex == 5)
        #expect(stopAtOne.rawValue == 1.0)

        let stopAtHalf = ZoomStop.from(factor: 0.5)
        #expect(stopAtHalf.stepIndex == 0)
        #expect(stopAtHalf.rawValue == 0.5)

        let stopAtFour = ZoomStop.from(factor: 4.0)
        #expect(stopAtFour.stepIndex == 35)
        #expect(stopAtFour.rawValue == 4.0)
    }

    @Test func dragLeftSteppingProgression() {
        var current = ZoomStop.from(factor: 1.0)
        let next = current.nextClamped()
        #expect(approx(CGFloat(next.rawValue), 1.1))
        current = next
        #expect(current.stepIndex == 6)
    }

    @Test func dragRightSteppingProgression() {
        var current = ZoomStop.from(factor: 2.0)
        let prev = current.previousClamped()
        #expect(approx(CGFloat(prev.rawValue), 1.9))
        current = prev
        #expect(current.stepIndex == 14)
    }

    @Test func discreteStepBoundaryEndstops() {
        let atMin = ZoomStop.from(factor: 0.5)
        #expect(atMin.previousClamped() == atMin)

        let atMax = ZoomStop.from(factor: 4.0)
        #expect(atMax.nextClamped() == atMax)
    }

    @Test func sensorSwitchingBoundaryAtOnePointZero() {
        let caps = Self.dualWideCamera
        // 0.9x is in the Ultra Wide range (< 2.0 device factor)
        let factorAtPointNine = caps.deviceFactor(forDisplayZoom: 0.9)
        #expect(factorAtPointNine < 2.0, "0.9x must use ultra wide sensor")

        // 1.0x is on the Main sensor (>= 2.0 device factor)
        let factorAtOne = caps.deviceFactor(forDisplayZoom: 1.0)
        #expect(factorAtOne >= 2.0, "1.0x must use main sensor")
    }

    @Test func ribOffsetMovesWithFinger() {
        let stop1 = ZoomStop.from(factor: 1.0)
        let stop2 = ZoomStop.from(factor: 1.1)

        let angle1 = stop1.rotationAngleDegrees
        let angle2 = stop2.rotationAngleDegrees

        #expect(angle2 > angle1, "Angle increases as zoom factor increases")
        let ribSpacing: CGFloat = 16.0
        let offset1 = -CGFloat(angle1) * (ribSpacing / 18.0)
        let offset2 = -CGFloat(angle2) * (ribSpacing / 18.0)
        #expect(offset2 < offset1, "Ribs shift left when zooming in (dragging left)")
    }

    @Test func frontCameraIsNotZoomable() {
        let caps = ZoomCapabilities.none
        #expect(!caps.isZoomable)
    }

    // MARK: - Physical buttons

    @Test func primaryButtonCapturesWithCameraControl() {
        #expect(PrimaryButtonAction.resolve(hasCameraControl: true) == .capture)
    }

    @Test func primaryButtonFlipsWithoutCameraControl() {
        #expect(PrimaryButtonAction.resolve(hasCameraControl: false) == .flipCamera)
    }

    // MARK: - Camera flip & debouncing (change 061 & change 072)

    @Test func cameraControllerInitialSwitchStateIsFalse() {
        let controller = CameraController()
        #expect(!controller.isSwitchingCamera)
        #expect(controller.lastBackCameraZoom == 1.0)
    }

    @Test func cameraControllerFlipGuardedWhenSessionNotRunning() {
        let controller = CameraController()
        #expect(!controller.isSessionRunning)
        controller.toggleCameraPosition()
        #expect(!controller.isSwitchingCamera)
    }

    @Test func shutterAnimationTriggersAndResets() async throws {
        let context = Self.makeInMemoryContext()
        let store = SessionStore(modelContext: context)
        let viewModel = RollFlowViewModel(modelContext: context, sessionStore: store)

        #expect(!viewModel.isShutterPressed)
        let task = viewModel.triggerShutterAnimation(durationNanoseconds: 20_000_000)
        #expect(viewModel.isShutterPressed)

        await task.value
        #expect(!viewModel.isShutterPressed)
    }

    @Test func shutterTappedActivatesShutterPressedState() async throws {
        let context = Self.makeInMemoryContext()
        let store = SessionStore(modelContext: context)
        let viewModel = RollFlowViewModel(modelContext: context, sessionStore: store)
        let user = UserProfile(appleUserID: "user-1", name: "Tester")

        #expect(!viewModel.isShutterPressed)
        await viewModel.shutterTapped(currentUser: user)
        #expect(viewModel.isShutterPressed)

        await viewModel.shutterAnimationTask?.value
        #expect(!viewModel.isShutterPressed)
    }

    @Test func shutterHapticExecutesSafely() {
        HapticService.shared.playShutterClick()
    }

    @Test func flashCyclesOffOn() {
        let camera = CameraController()
        camera.flashChoice = .off
        camera.handleSecondaryButton()
        #expect(camera.flashChoice == .on)
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

    @Test func captureSessionIsPortraitWhileOutsideRespectsDeviceDefault() {
        #expect(OrientationLock.defaultMask(for: .phone) == .portrait)
        #expect(OrientationLock.defaultMask(for: .pad) == .all)
        #expect(OrientationLock.mask(isCaptureSessionVisible: true, idiom: .phone) == .portrait)
        #expect(OrientationLock.mask(isCaptureSessionVisible: false, idiom: .phone) == .portrait)
        #expect(OrientationLock.mask(isCaptureSessionVisible: true, idiom: .pad) == .portrait)
        #expect(OrientationLock.mask(isCaptureSessionVisible: false, idiom: .pad) == .all)
    }

    @Test func resetToPortraitSetsDeviceDefaultMask() {
        OrientationLock.set(.landscape)
        #expect(OrientationLock.mask == .landscape)
        OrientationLock.resetToPortrait()
        #expect(OrientationLock.mask == OrientationLock.defaultMask())
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

    @Test func shotsRemainingCountsDown() {
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

        #expect(viewModel.shotsRemaining == 36)
        #expect(viewModel.shotsRemainingText == "36")

        session.slotsUsed = 12
        #expect(viewModel.shotsRemaining == 24)
        #expect(viewModel.shotsRemainingText == "24")

        session.slotsUsed = 36
        #expect(viewModel.shotsRemaining == 0)
        #expect(viewModel.shotsRemainingText == "0")

        session.slotsUsed = 40
        #expect(viewModel.shotsRemaining == 0)
    }

    @Test func shotsRemainingStartsAtZeroWithoutSession() {
        let context = Self.makeInMemoryContext()
        let store = SessionStore(modelContext: context)
        let viewModel = RollFlowViewModel(modelContext: context, sessionStore: store)

        #expect(viewModel.shotsRemaining == 0)
        #expect(viewModel.shotsRemainingText == "0")
        let body = UIImage(named: "CameraBodyShape")
        #expect(body != nil)
        #expect(body?.size.width == 874)
        #expect(body?.size.height == 402)
        #expect(UIImage(named: "CameraShutterWell") != nil)
        #expect(UIImage(named: "CameraDialOuter") != nil)
        #expect(UIImage(named: "CameraDialInner") != nil)
    }

    @Test func shotsLeftDialViewDigitsAndClamping() {
        let dial36 = ShotsLeftDialView(shotsRemaining: 36, totalShots: 36)
        #expect(dial36.safeShots == 36)
        #expect(dial36.tensDigit == 3)
        #expect(dial36.onesDigit == 6)
        #expect(dial36.isTensBlankAbove)
        #expect(dial36.isOnesBlankAbove)
        #expect(dial36.belowTensDigit == 2)
        #expect(dial36.belowOnesDigit == 5)

        let dial35 = ShotsLeftDialView(shotsRemaining: 35, totalShots: 36)
        #expect(dial35.safeShots == 35)
        #expect(dial35.tensDigit == 3)
        #expect(dial35.onesDigit == 5)
        #expect(dial35.isTensBlankAbove)
        #expect(!dial35.isOnesBlankAbove)
        #expect(dial35.aboveOnesDigit == 6)
        #expect(dial35.belowTensDigit == 2)
        #expect(dial35.belowOnesDigit == 4)

        let dial24 = ShotsLeftDialView(shotsRemaining: 24, totalShots: 24)
        #expect(dial24.safeShots == 24)
        #expect(dial24.tensDigit == 2)
        #expect(dial24.onesDigit == 4)
        #expect(dial24.isTensBlankAbove)
        #expect(dial24.isOnesBlankAbove)
        #expect(dial24.belowTensDigit == 1)
        #expect(dial24.belowOnesDigit == 3)

        let dial23 = ShotsLeftDialView(shotsRemaining: 23, totalShots: 24)
        #expect(dial23.safeShots == 23)
        #expect(dial23.tensDigit == 2)
        #expect(dial23.onesDigit == 3)
        #expect(dial23.isTensBlankAbove)
        #expect(!dial23.isOnesBlankAbove)
        #expect(dial23.aboveOnesDigit == 4)
        #expect(dial23.belowTensDigit == 1)
        #expect(dial23.belowOnesDigit == 2)

        let dial20 = ShotsLeftDialView(shotsRemaining: 20, totalShots: 24)
        #expect(dial20.tensDigit == 2)
        #expect(dial20.onesDigit == 0)
        #expect(dial20.isTensBlankAbove)
        #expect(dial20.aboveOnesDigit == 1)
        #expect(dial20.belowTensDigit == 1)
        #expect(dial20.belowOnesDigit == 9)

        let dial19 = ShotsLeftDialView(shotsRemaining: 19, totalShots: 24)
        #expect(dial19.tensDigit == 1)
        #expect(dial19.onesDigit == 9)
        #expect(!dial19.isTensBlankAbove)
        #expect(dial19.aboveTensDigit == 2)
        #expect(dial19.aboveOnesDigit == 0)
        #expect(dial19.belowTensDigit == 0)
        #expect(dial19.belowOnesDigit == 8)

        let dial0 = ShotsLeftDialView(shotsRemaining: 0, totalShots: 36)
        #expect(dial0.safeShots == 0)
        #expect(dial0.tensDigit == 0)
        #expect(dial0.onesDigit == 0)
        #expect(!dial0.isTensBlankAbove)
        #expect(dial0.aboveTensDigit == 1)
        #expect(dial0.aboveOnesDigit == 1)
        #expect(dial0.belowTensDigit == 0)
        #expect(dial0.belowOnesDigit == 0)
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
        let output = FilmFilterPipeline().apply(.digicam, to: Self.orange)
        let p = Self.pixel(of: output)

        #expect(p.r > p.b + 20)
    }

    @Test func previewAndPhotoUseTheSameResult() {
        for look in [FilmLook.noir, .digicam] {
            let preview = Self.pixel(of: FilmFilterPipeline().apply(look, to: Self.orange))
            let photo = Self.pixel(of: FilmFilterPipeline().apply(look, to: Self.orange))
            #expect(preview == photo)
        }
    }

    @Test func rollFiltersMapToLooks() {
        #expect(RollFilter.cinematicBW400.look == .noir)
        #expect(RollFilter.colorPrint200.look == .digicam)
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

    // MARK: - Viewfinder and Photo 3:4 / 4:3 Aspect Ratio (change 071)

    @Test func photoEncoderCropsNonStandardLandscapeImageTo4x3() {
        // 16:9 widescreen input (1920 × 1080)
        let wideImage = CIImage(color: CIColor(red: 0.1, green: 0.5, blue: 0.8))
            .cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let cropped = FilmPhotoEncoder.cropToStandardAspectRatio(wideImage)

        #expect(abs(cropped.extent.width - 1440) < 0.001)
        #expect(abs(cropped.extent.height - 1080) < 0.001)
        #expect(abs(cropped.extent.origin.x - 0) < 0.001)
        #expect(abs(cropped.extent.origin.y - 0) < 0.001)
        #expect(abs((cropped.extent.width / cropped.extent.height) - (4.0 / 3.0)) < 0.001)
    }

    @Test func photoEncoderCropsNonStandardPortraitImageTo3x4() {
        // 9:16 vertical input (1080 × 1920)
        let tallImage = CIImage(color: CIColor(red: 0.1, green: 0.5, blue: 0.8))
            .cropped(to: CGRect(x: 0, y: 0, width: 1080, height: 1920))
        let cropped = FilmPhotoEncoder.cropToStandardAspectRatio(tallImage)

        #expect(abs(cropped.extent.width - 1080) < 0.001)
        #expect(abs(cropped.extent.height - 1440) < 0.001)
        #expect(abs(cropped.extent.origin.x - 0) < 0.001)
        #expect(abs(cropped.extent.origin.y - 0) < 0.001)
        #expect(abs((cropped.extent.width / cropped.extent.height) - (3.0 / 4.0)) < 0.001)
    }

    @Test func photoEncoderPreservesStandard4x3And3x4Images() {
        let standardLandscape = CIImage(color: CIColor(red: 0.2, green: 0.6, blue: 0.9))
            .cropped(to: CGRect(x: 0, y: 0, width: 4032, height: 3024))
        let resultLandscape = FilmPhotoEncoder.cropToStandardAspectRatio(standardLandscape)
        #expect(resultLandscape.extent == standardLandscape.extent)

        let standardPortrait = CIImage(color: CIColor(red: 0.2, green: 0.6, blue: 0.9))
            .cropped(to: CGRect(x: 0, y: 0, width: 3024, height: 4032))
        let resultPortrait = FilmPhotoEncoder.cropToStandardAspectRatio(standardPortrait)
        #expect(resultPortrait.extent == standardPortrait.extent)
    }

    @Test func photoEncoderEncodesNonStandardImageToExactTargetDimensions() throws {
        // 16:9 input encoded via jpegData
        let wideImage = CIImage(color: CIColor(red: 0.3, green: 0.7, blue: 0.2))
            .cropped(to: CGRect(x: 0, y: 0, width: 3840, height: 2160))
        let data = try #require(FilmPhotoEncoder.jpegData(from: wideImage))

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int else {
            Issue.record("Failed to read image properties from encoded JPEG")
            return
        }

        #expect(pixelWidth == 2048)
        #expect(pixelHeight == 1536)
        #expect(Double(pixelWidth) / Double(pixelHeight) == 4.0 / 3.0)
    }

    @Test func movieWriterCropsNonStandardVideoTo4x3Landscape() throws {
        let rawSize = CGSize(width: 1920, height: 1080)
        let (crop, targetSize) = LivePhotoMovieWriter.cropRect(for: rawSize, transform: .identity)

        let rect = try #require(crop)
        #expect(rect.origin.x == 240)
        #expect(rect.origin.y == 0)
        #expect(rect.width == 1440)
        #expect(rect.height == 1080)
        #expect(targetSize.width == 1440)
        #expect(targetSize.height == 1080)
    }

    @Test func movieWriterCropsNonStandardVideoTo3x4Portrait() throws {
        let rawSize = CGSize(width: 1080, height: 1920)
        let (crop, targetSize) = LivePhotoMovieWriter.cropRect(for: rawSize, transform: .identity)

        let rect = try #require(crop)
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 240)
        #expect(rect.width == 1080)
        #expect(rect.height == 1440)
        #expect(targetSize.width == 1080)
        #expect(targetSize.height == 1440)
    }

    @Test func movieWriterLeavesStandard4x3VideoUncropped() {
        let rawLandscape = CGSize(width: 1920, height: 1440)
        let (cropLandscape, _) = LivePhotoMovieWriter.cropRect(for: rawLandscape, transform: .identity)
        #expect(cropLandscape == nil)

        // Portrait video delivered with 90-degree transform from 4:3 camera buffer
        let transform90 = CGAffineTransform(rotationAngle: .pi / 2)
        let (cropPortrait, _) = LivePhotoMovieWriter.cropRect(for: rawLandscape, transform: transform90)
        #expect(cropPortrait == nil)
    }
}
