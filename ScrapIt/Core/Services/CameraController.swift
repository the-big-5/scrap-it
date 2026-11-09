import AVFoundation
import CoreImage
import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

enum CameraFlashChoice: String, CaseIterable {
    case off = "OFF"
    case on = "ON"
    case auto = "AUTO"

    var captureMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: .off
        case .on: .on
        case .auto: .auto
        }
    }
}

/// A taken shot: the filtered still right away, and the filtered Live Photo movie when it is ready.
struct CapturedShot {
    let imageData: Data
    /// `nil` when Live Photo was off or unsupported. Resolves to `nil` if the movie failed.
    let livePhotoMovie: Task<Data?, Never>?
}

/// Main-actor face of `CameraEngine` for the Capture session screen:
/// filtered preview, zoom, flip, flash, Live Photo, physical buttons and the Camera Adjustments pop-up.
@Observable
final class CameraController {
    var flashChoice: CameraFlashChoice = .auto
    var isLivePhotoEnabled: Bool = true
    private(set) var isUsingFrontCamera: Bool = false
    private(set) var zoomFactor: CGFloat = 1.0
    private(set) var zoomCapabilities: ZoomCapabilities = .none
    private(set) var isCameraAuthorized: Bool = false
    /// The capture session is really running (from AVFoundation notifications).
    private(set) var isSessionRunning: Bool = false
    private(set) var isLiveSupported: Bool = false
    /// "LIVE" badge while the Live Photo movie records.
    private(set) var isRecordingLive: Bool = false
    private(set) var hasCameraControl: Bool = false
    private(set) var isCapturing: Bool = false
    var shutterFlashOpacity: Double = 0.0
    /// "Turn On Camera Adjustments" alert.
    var showsCameraAdjustmentsPrompt: Bool = false

    let engine = CameraEngine()
    @ObservationIgnored private var prompt = CameraAdjustmentsPrompt()
    @ObservationIgnored private var shotSequenceNumber: Int = 0
    @ObservationIgnored private var isStarting = false

    var previewRenderer: PreviewRenderer? { engine.renderer }

    var canCapture: Bool { !isCapturing }

    init() {
        engine.onWillCapturePhoto = { [weak self] in
            self?.flashScreen()
        }
        engine.onLiveRecordingChanged = { [weak self] recording in
            self?.isRecordingLive = recording
        }
        engine.onZoomChanged = { [weak self] zoom in
            guard let self, !self.isUsingFrontCamera else { return }
            self.zoomFactor = zoom
        }
        engine.onCameraControlsActivated = { [weak self] in
            self?.confirmCameraAdjustmentsOn()
        }
        engine.onRunningChanged = { [weak self] running in
            self?.isSessionRunning = running
        }
    }

    // MARK: - Session

    /// Uses the roll's filter for preview, photo and Live Photo.
    func setFilter(_ filter: RollFilter) {
        engine.look = filter.look
    }

    func startSession() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                isCameraAuthorized = false
                return
            }
        default:
            isCameraAuthorized = false
            return
        }
        isCameraAuthorized = true

        guard await engine.start() else { return }
        isLiveSupported = await engine.isLivePhotoAvailable()
        hasCameraControl = await engine.supportsCameraControl()
        isUsingFrontCamera = false
        zoomCapabilities = await engine.resetZoom()
        zoomFactor = 1
        scheduleCameraAdjustmentsPrompt()
    }

    func stopSession() {
        engine.stop()
    }

    // MARK: - Controls

    func cycleFlash() {
        let all = CameraFlashChoice.allCases
        if let index = all.firstIndex(of: flashChoice) {
            flashChoice = all[(index + 1) % all.count]
        }
    }

    /// Updates rotation offset when simulating landscape in a portrait window or handling locked landscape.
    func setSimulatedLandscapeSide(
        _ side: RollCameraOrientation.LandscapeSide,
        isPortrait: Bool,
        windowOrientation: UIInterfaceOrientation = .unknown
    ) {
        engine.setSimulatedLandscapeSide(side, isPortrait: isPortrait, windowOrientation: windowOrientation)
    }

    func toggleCameraPosition() {
        guard isSessionRunning, !isCapturing else { return }
        Task {
            guard let position = await engine.switchCamera() else { return }
            isUsingFrontCamera = position == .front
            isLiveSupported = await engine.isLivePhotoAvailable()
            zoomCapabilities = await engine.resetZoom()
            zoomFactor = 1
        }
    }

    /// Wheel drag: follows the finger.
    func setZoomFactor(_ zoom: CGFloat) {
        guard !isUsingFrontCamera, zoomCapabilities.isZoomable else { return }
        zoomFactor = zoomCapabilities.quantized(zoom)
        engine.setZoom(zoomFactor)
    }

    /// Wheel tap to a lens value: smooth move.
    func rampZoom(to zoom: CGFloat) {
        guard !isUsingFrontCamera, zoomCapabilities.isZoomable else { return }
        zoomFactor = zoomCapabilities.quantized(zoom)
        engine.rampZoom(to: zoomFactor)
    }

    // MARK: - Physical buttons

    /// Camera Control click / volume down.
    func handlePrimaryButton(capture: () -> Void) {
        switch PrimaryButtonAction.resolve(hasCameraControl: hasCameraControl) {
        case .capture:
            capture()
        case .flipCamera:
            toggleCameraPosition()
        }
    }

    /// Volume up.
    func handleSecondaryButton() {
        cycleFlash()
    }

    // MARK: - Camera Adjustments pop-up

    func confirmCameraAdjustmentsOn() {
        showsCameraAdjustmentsPrompt = false
        prompt.confirm()
    }

    func dismissCameraAdjustmentsPromptForever() {
        showsCameraAdjustmentsPrompt = false
        prompt.dismissForever()
    }

    private func scheduleCameraAdjustmentsPrompt() {
        guard prompt.shouldShow(hasCameraControl: hasCameraControl) else { return }
        Task {
            // Let the camera appear first.
            try? await Task.sleep(for: .seconds(1))
            guard isSessionRunning, !prompt.isConfirmed else { return }
            showsCameraAdjustmentsPrompt = true
        }
    }

    // MARK: - Capture

    func captureShot(filter: RollFilter, rollName: String) async -> CapturedShot {
        shotSequenceNumber += 1
        guard isSessionRunning else {
            // Simulator / no camera: placeholder frame.
            flashScreen()
            let data = Self.generateFilmFrameData(
                filter: filter,
                shotIndex: shotSequenceNumber,
                rollName: rollName,
                isLivePhoto: false
            )
            return CapturedShot(imageData: data, livePhotoMovie: nil)
        }

        isCapturing = true
        defer { isCapturing = false }
        let look = filter.look
        let wantsLive = isLivePhotoEnabled && isLiveSupported

        let captured: CapturedPhoto
        do {
            captured = try await engine.capturePhoto(
                flashMode: flashChoice.captureMode,
                look: look,
                livePhoto: wantsLive
            )
        } catch {
            let data = Self.generateFilmFrameData(
                filter: filter,
                shotIndex: shotSequenceNumber,
                rollName: rollName,
                isLivePhoto: false
            )
            return CapturedShot(imageData: data, livePhotoMovie: nil)
        }

        let contentIdentifier = captured.liveMovie == nil ? nil : UUID().uuidString
        let image = captured.image
        let imageData = await Task.detached(priority: .userInitiated) {
            FilmPhotoEncoder.jpegData(from: image, contentIdentifier: contentIdentifier)
        }.value ?? Data()

        guard let movie = captured.liveMovie, let contentIdentifier else {
            return CapturedShot(imageData: imageData, livePhotoMovie: nil)
        }
        let movieTask = Task.detached(priority: .utility) { () -> Data? in
            await Self.filteredMovieData(from: movie, look: look, contentIdentifier: contentIdentifier)
        }
        return CapturedShot(imageData: imageData, livePhotoMovie: movieTask)
    }

    /// Filters the raw Live Photo movie and returns it as data. `nil` if anything fails
    /// (the still photo is then kept as a normal photo).
    nonisolated private static func filteredMovieData(
        from movie: LivePhotoMovie,
        look: FilmLook,
        contentIdentifier: String
    ) async -> Data? {
        let destination = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        defer {
            try? FileManager.default.removeItem(at: movie.url)
            try? FileManager.default.removeItem(at: destination)
        }
        do {
            try await LivePhotoMovieWriter.write(
                from: movie.url,
                to: destination,
                look: look,
                contentIdentifier: contentIdentifier,
                photoDisplayTime: movie.photoDisplayTime
            )
            return try Data(contentsOf: destination)
        } catch {
            return nil
        }
    }

    private func flashScreen() {
        shutterFlashOpacity = 0.85
        Task {
            try? await Task.sleep(for: .milliseconds(110))
            shutterFlashOpacity = 0.0
        }
    }

    static func generateFilmFrameData(
        filter: RollFilter,
        shotIndex: Int,
        rollName: String,
        isLivePhoto: Bool
    ) -> Data {
        #if canImport(UIKit)
        let size = CGSize(width: 720, height: 540)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            if filter == .cinematicBW400 {
                UIColor(white: 0.14, alpha: 1.0).setFill()
                ctx.fill(rect)
                UIColor(white: 0.28, alpha: 1.0).setFill()
                ctx.fill(CGRect(x: 40, y: 40, width: size.width - 80, height: size.height - 80))
            } else {
                UIColor(red: 0.28, green: 0.20, blue: 0.14, alpha: 1.0).setFill()
                ctx.fill(rect)
                UIColor(red: 0.86, green: 0.65, blue: 0.38, alpha: 1.0).setFill()
                ctx.fill(CGRect(x: 40, y: 40, width: size.width - 80, height: size.height - 80))
            }

            let stamp = "\(rollName.uppercased()) • SHOT #\(String(format: "%02d", shotIndex)) • \(filter.shortLabel)\(isLivePhoto ? " • LIVE" : "")"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            stamp.draw(at: CGPoint(x: 64, y: size.height - 92), withAttributes: attrs)
        }
        return image.jpegData(compressionQuality: 0.85) ?? Data()
        #else
        return Data()
        #endif
    }
}
