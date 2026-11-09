import AVFoundation
import CoreImage
import UIKit

nonisolated enum CameraEngineError: Error {
    case captureFailed
}

/// Raw (unfiltered) Live Photo movie in the temporary folder.
nonisolated struct LivePhotoMovie: Sendable {
    let url: URL
    let photoDisplayTime: CMTime
}

nonisolated struct CapturedPhoto: @unchecked Sendable {
    /// Final photo, already filtered.
    let image: CIImage
    let liveMovie: LivePhotoMovie?
}

/// Wraps `AVCaptureSession` (ported from the POC `CameraManager`): configuration, filtered preview frames,
/// photo + Live Photo capture, zoom, rotation and the Camera Control "Zoom" slider.
/// All session work runs on `sessionQueue`; callbacks are delivered on the main actor.
nonisolated final class CameraEngine: NSObject, @unchecked Sendable {
    let renderer = PreviewRenderer()

    var onWillCapturePhoto: (@MainActor () -> Void)?
    var onLiveRecordingChanged: (@MainActor (Bool) -> Void)?
    /// The back camera's zoom changed, from any source (Camera Control slide, wheel, lens ramp).
    /// Display zoom on 0.1 steps.
    var onZoomChanged: (@MainActor (CGFloat) -> Void)?
    /// The Camera Control overlay opened from a light press (Camera Adjustments is on).
    var onCameraControlsActivated: (@MainActor () -> Void)?
    var onRunningChanged: (@MainActor (Bool) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "ScrapIt.camera.session")
    private let videoQueue = DispatchQueue(label: "ScrapIt.camera.video", qos: .userInteractive)
    private let processingQueue = DispatchQueue(label: "ScrapIt.camera.processing", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()

    // Only touched on sessionQueue.
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var wantsRunning = false
    private var captureDelegates: [Int64: PhotoCaptureDelegate] = [:]
    private var zoomCapabilities = ZoomCapabilities.none
    private var backZoomCapabilities = ZoomCapabilities.none
    private var currentDisplayZoom: CGFloat = 1
    private var hasCameraControl = false
    private var rotationAngle: CGFloat = 0
    private var baseRotationAngle: CGFloat = 0
    private var simulatedLandscapeDelta: CGFloat = 0
    /// `AVCaptureSlider` "Zoom" (iOS 18+).
    private var zoomSlider: AnyObject?
    /// Watches the camera's real `videoZoomFactor`, so the screen follows every zoom change.
    private var zoomObservation: NSKeyValueObservation?
    private var lastReportedZoom: CGFloat?

    // Only touched on the main thread.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    // Wheel zoom: only the latest value is applied so updates do not pile up.
    private let zoomLock = NSLock()
    private var pendingZoom: CGFloat?

    private let previewPipeline = FilmFilterPipeline() // videoQueue
    private let photoPipeline = FilmFilterPipeline()   // processingQueue
    private let lookLock = NSLock()
    private var currentLook: FilmLook = .chrome

    var look: FilmLook {
        get { lookLock.withLock { currentLook } }
        set { lookLock.withLock { currentLook = newValue } }
    }

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(sessionRuntimeError),
                           name: AVCaptureSession.runtimeErrorNotification, object: session)
        center.addObserver(self, selector: #selector(sessionDidStartRunning),
                           name: AVCaptureSession.didStartRunningNotification, object: session)
        center.addObserver(self, selector: #selector(sessionDidStopRunning),
                           name: AVCaptureSession.didStopRunningNotification, object: session)
    }

    // MARK: - Lifecycle

    /// Configures once, then runs the session. `false` when no camera is available (e.g. Simulator).
    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !self.isConfigured {
                    self.isConfigured = self.configureSession()
                }
                guard self.isConfigured else {
                    continuation.resume(returning: false)
                    return
                }
                self.wantsRunning = true
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume(returning: true)
            }
        }
    }

    func stop() {
        sessionQueue.async {
            self.wantsRunning = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSession() -> Bool {
        guard let device = Self.camera(at: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }

        session.beginConfiguration()
        session.sessionPreset = .photo
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)
        videoInput = input
        observeZoom(of: input.device)

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput), session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return false
        }
        session.addOutput(videoOutput)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .balanced
        // Live Photo without audio: the session has no audio input.
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported

        updateConnections(for: .back)
        session.commitConfiguration()
        // Applied again after commit: connections can be recreated when the configuration is applied.
        updateConnections(for: .back)
        updateMaxPhotoDimensions(for: device)
        makeRotationCoordinator(for: device)

        if #available(iOS 18.0, *), session.supportsControls {
            session.setControlsDelegate(self, queue: sessionQueue)
            hasCameraControl = true
        }
        return true
    }

    func supportsCameraControl() async -> Bool {
        await onSessionQueue { self.hasCameraControl }
    }

    func isLivePhotoAvailable() async -> Bool {
        await onSessionQueue { self.photoOutput.isLivePhotoCaptureEnabled }
    }

    private func onSessionQueue<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            sessionQueue.async { continuation.resume(returning: work()) }
        }
    }

    // MARK: - Zoom

    /// Recomputes the zoom range of the active camera and goes back to 1×.
    /// The front camera has no zoom and stays at its widest view.
    func resetZoom() async -> ZoomCapabilities {
        await onSessionQueue { self.resetZoomForCurrentDevice() }
    }

    /// Wheel zoom: follows the finger, no ramp.
    func setZoom(_ zoom: CGFloat) {
        let needsSchedule = zoomLock.withLock { () -> Bool in
            defer { pendingZoom = zoom }
            return pendingZoom == nil
        }
        guard needsSchedule else { return }
        sessionQueue.async {
            guard let zoom = self.zoomLock.withLock({ () -> CGFloat? in
                defer { self.pendingZoom = nil }
                return self.pendingZoom
            }) else { return }
            self.applyZoom(zoom, ramp: false)
        }
    }

    /// Lens jumps (wheel tap): smooth move to the target.
    func rampZoom(to zoom: CGFloat) {
        sessionQueue.async {
            self.applyZoom(zoom, ramp: true)
        }
    }

    private func resetZoomForCurrentDevice() -> ZoomCapabilities {
        guard let device = videoInput?.device else { return .none }
        let capabilities = device.position == .back ? Self.zoomCapabilities(for: device) : .none
        zoomCapabilities = capabilities
        if device.position == .back { backZoomCapabilities = capabilities }
        currentDisplayZoom = 1
        let target = device.position == .back
            ? capabilities.deviceFactor(forDisplayZoom: 1)
            : device.minAvailableVideoZoomFactor
        setVideoZoomFactor(target, on: device, ramp: false)
        updateCameraControls()
        return capabilities
    }

    private func applyZoom(_ zoom: CGFloat, ramp: Bool) {
        guard let device = videoInput?.device, device.position == .back, zoomCapabilities.isZoomable else { return }
        setVideoZoomFactor(zoomCapabilities.deviceFactor(forDisplayZoom: zoom), on: device, ramp: ramp)
        currentDisplayZoom = zoomCapabilities.clamped(zoom)
        if #available(iOS 18.0, *) {
            updateZoomSliderValue()
        }
    }

    private func setVideoZoomFactor(_ factor: CGFloat, on device: AVCaptureDevice, ramp: Bool) {
        let factor = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        do {
            try device.lockForConfiguration()
            if ramp {
                device.ramp(toVideoZoomFactor: factor, withRate: 4)
            } else {
                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                device.videoZoomFactor = factor
            }
            device.unlockForConfiguration()
        } catch {
            // Device busy; skip this zoom change.
        }
    }

    private static func zoomCapabilities(for device: AVCaptureDevice) -> ZoomCapabilities {
        ZoomCapabilities.make(
            hasUltraWide: device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera },
            switchOverFactors: device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) },
            secondaryNativeFactors: device.activeFormat.secondaryNativeResolutionZoomFactors,
            minDeviceFactor: device.minAvailableVideoZoomFactor,
            maxDeviceFactor: device.maxAvailableVideoZoomFactor
        )
    }

    // MARK: - Camera Control "Zoom" slider

    @available(iOS 18.0, *)
    private func updateZoomSliderValue() {
        guard let slider = zoomSlider as? AVCaptureSlider else { return }
        let value = Float(currentDisplayZoom)
        if abs(slider.value - value) > 0.001 {
            slider.value = value
        }
    }

    /// Slide on Camera Control: same zoom as the screen wheel.
    private func zoomFromCameraControl(_ value: Float) {
        let zoom = zoomCapabilities.quantized(CGFloat(value))
        applyZoom(zoom, ramp: false)
        report(zoom)
    }

    private func observeZoom(of device: AVCaptureDevice) {
        lastReportedZoom = nil
        zoomObservation = device.observe(\.videoZoomFactor, options: [.new]) { [weak self] device, _ in
            let factor = device.videoZoomFactor
            self?.sessionQueue.async { self?.reportZoom(deviceFactor: factor, of: device) }
        }
    }

    private func reportZoom(deviceFactor: CGFloat, of device: AVCaptureDevice) {
        guard videoInput?.device == device, device.position == .back, zoomCapabilities.isZoomable else { return }
        report(zoomCapabilities.quantized(zoomCapabilities.displayZoom(forDeviceFactor: deviceFactor)))
    }

    private func report(_ zoom: CGFloat) {
        guard zoom != lastReportedZoom else { return }
        lastReportedZoom = zoom
        Task { @MainActor in self.onZoomChanged?(zoom) }
    }

    /// One Camera Control control: **Zoom**, a slider from the device minimum to 4× in 0.1 steps
    /// (same as the screen wheel), with the lens values marked. No front camera option.
    /// Disabled on the front camera (no zoom). Rebuilt whenever the camera changes.
    private func updateCameraControls() {
        guard #available(iOS 18.0, *), hasCameraControl else { return }
        session.beginConfiguration()
        for control in session.controls {
            session.removeControl(control)
        }
        zoomSlider = nil
        let range = backZoomCapabilities.isZoomable ? backZoomCapabilities : ZoomCapabilities.none
        let slider = AVCaptureSlider(
            "Zoom",
            symbolName: "plus.magnifyingglass",
            in: Float(range.minZoom)...Float(max(range.maxZoom, range.minZoom + ZoomCapabilities.step)),
            step: Float(ZoomCapabilities.step)
        )
        slider.localizedValueFormat = "%@×"
        slider.prominentValues = range.presets.map { Float($0) }
        slider.isEnabled = videoInput?.device.position == .back && range.isZoomable
        slider.setActionQueue(sessionQueue) { [weak self] value in
            self?.zoomFromCameraControl(value)
        }
        if session.canAddControl(slider) {
            session.addControl(slider)
            zoomSlider = slider
            updateZoomSliderValue()
        }
        session.commitConfiguration()
    }

    // MARK: - Flip

    func switchCamera() async -> AVCaptureDevice.Position? {
        await onSessionQueue { self.toggleCameraPosition() }
    }

    private func toggleCameraPosition() -> AVCaptureDevice.Position? {
        guard let current = videoInput else { return nil }
        let position: AVCaptureDevice.Position = current.device.position == .back ? .front : .back
        guard let device = Self.camera(at: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return nil }

        session.beginConfiguration()
        session.removeInput(current)
        guard session.canAddInput(input) else {
            session.addInput(current)
            session.commitConfiguration()
            return nil
        }
        session.addInput(input)
        videoInput = input
        observeZoom(of: input.device)
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        updateConnections(for: position)
        session.commitConfiguration()
        // Without this the image can fall back to the sensor orientation after a flip.
        updateConnections(for: position)
        updateMaxPhotoDimensions(for: device)
        // Each sensor has its own base orientation: recompute the angle.
        makeRotationCoordinator(for: device)
        return position
    }

    // MARK: - Capture

    /// Full-resolution photo with the same filter as the preview.
    /// With `livePhoto`, the raw Live Photo movie is returned too (filtered later).
    func capturePhoto(flashMode: AVCaptureDevice.FlashMode, look: FilmLook,
                      livePhoto: Bool) async throws -> CapturedPhoto {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                guard self.session.isRunning else {
                    continuation.resume(throwing: CameraEngineError.captureFailed)
                    return
                }
                let settings = AVCapturePhotoSettings()
                if self.photoOutput.supportedFlashModes.contains(flashMode) {
                    settings.flashMode = flashMode
                }
                settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
                settings.photoQualityPrioritization = .balanced
                if livePhoto && self.photoOutput.isLivePhotoCaptureEnabled {
                    settings.livePhotoMovieFileURL = FileManager.default.temporaryDirectory
                        .appending(path: "\(UUID().uuidString).mov")
                }

                let id = settings.uniqueID
                let delegate = PhotoCaptureDelegate(
                    willCapture: {
                        Task { @MainActor in self.onWillCapturePhoto?() }
                    },
                    liveRecordingChanged: { isRecording in
                        Task { @MainActor in self.onLiveRecordingChanged?(isRecording) }
                    },
                    completion: { result in
                        self.sessionQueue.async { self.captureDelegates[id] = nil }
                        switch result {
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        case .success(let (data, liveMovie)):
                            self.processingQueue.async {
                                guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
                                    if let liveMovie { try? FileManager.default.removeItem(at: liveMovie.url) }
                                    continuation.resume(throwing: CameraEngineError.captureFailed)
                                    return
                                }
                                let filtered = self.photoPipeline.apply(look, to: image)
                                continuation.resume(returning: CapturedPhoto(image: filtered, liveMovie: liveMovie))
                            }
                        }
                    })
                self.captureDelegates[id] = delegate
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    // MARK: - Session notifications

    @objc private func sessionDidStartRunning(_ notification: Notification) {
        Task { @MainActor in self.onRunningChanged?(true) }
    }

    @objc private func sessionDidStopRunning(_ notification: Notification) {
        Task { @MainActor in self.onRunningChanged?(false) }
    }

    @objc private func sessionRuntimeError(_ notification: Notification) {
        sessionQueue.async {
            if self.wantsRunning && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    // MARK: - Helpers

    /// Back camera uses a virtual (multi-lens) device so zoom switches lenses smoothly.
    private static func camera(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInWideAngleCamera]
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: position).devices
        for type in types {
            if let device = devices.first(where: { $0.deviceType == type }) {
                return device
            }
        }
        return nil
    }

    /// The angle comes from `RotationCoordinator` per camera (each sensor has its own base orientation)
    /// and follows the screen the preview is on. Preview and photo use the same angle, so photo = preview.
    private func makeRotationCoordinator(for device: AVCaptureDevice) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: self.renderer?.metalLayer)
            self.rotationCoordinator = coordinator
            self.rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview,
                                                           options: [.initial, .new]) { [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                self?.sessionQueue.async {
                    guard let self else { return }
                    self.baseRotationAngle = angle
                    let effective = (self.simulatedLandscapeDelta != 0)
                        ? (angle + self.simulatedLandscapeDelta).truncatingRemainder(dividingBy: 360)
                        : angle
                    let normalized = effective < 0 ? effective + 360 : effective
                    self.applyRotation(normalized, for: device)
                }
            }
        }
    }

    /// Updates rotation offset when simulating landscape in a portrait window or handling locked landscape.
    func setSimulatedLandscapeSide(
        _ side: RollCameraOrientation.LandscapeSide,
        isPortrait: Bool,
        windowOrientation: UIInterfaceOrientation = .unknown
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let newDelta = RollCameraOrientation.cameraRotationDelta(
                isPortraitWindow: isPortrait,
                windowInterfaceOrientation: windowOrientation,
                physicalSide: side
            )
            guard newDelta != self.simulatedLandscapeDelta else { return }
            self.simulatedLandscapeDelta = newDelta
            if let device = self.videoInput?.device {
                let effective = RollCameraOrientation.effectiveCameraAngle(
                    baseAngle: self.baseRotationAngle,
                    delta: newDelta
                )
                self.applyRotation(effective, for: device)
            }
        }
    }

    private func applyRotation(_ angle: CGFloat, for device: AVCaptureDevice) {
        // Ignore an angle from the previous camera if it was flipped again.
        guard videoInput?.device == device else { return }
        rotationAngle = angle
        updateConnections(for: device.position)
    }

    /// Rotates preview and photo with the screen; the front camera is mirrored like the system camera.
    private func updateConnections(for position: AVCaptureDevice.Position) {
        let connections = [videoOutput.connection(with: .video), photoOutput.connection(with: .video)]
        for connection in connections.compactMap({ $0 }) {
            if connection.isVideoRotationAngleSupported(rotationAngle) {
                connection.videoRotationAngle = rotationAngle
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = position == .front
            }
        }
    }

    private func updateMaxPhotoDimensions(for device: AVCaptureDevice) {
        let largest = device.activeFormat.supportedMaxPhotoDimensions.max {
            Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
        }
        if let largest {
            photoOutput.maxPhotoDimensions = largest
        }
    }
}

@available(iOS 18.0, *)
nonisolated extension CameraEngine: AVCaptureSessionControlsDelegate {
    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {}
    /// Only happens when the overlay opens from a light press, so it proves the setting is on.
    /// (`DidBecomeActive` can fire without a light press, so it is not used as proof.)
    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {
        Task { @MainActor in self.onCameraControlsActivated?() }
    }
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {}
}

nonisolated extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let renderer, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        renderer.display(previewPipeline.apply(look, to: CIImage(cvPixelBuffer: pixelBuffer)))
    }
}

private nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let willCapture: () -> Void
    private let liveRecordingChanged: (Bool) -> Void
    private let completion: (Result<(Data, LivePhotoMovie?), Error>) -> Void
    private var photoData: Data?
    private var processingError: Error?
    private var liveMovie: LivePhotoMovie?
    private var isRecordingLive = false

    init(willCapture: @escaping () -> Void, liveRecordingChanged: @escaping (Bool) -> Void,
         completion: @escaping (Result<(Data, LivePhotoMovie?), Error>) -> Void) {
        self.willCapture = willCapture
        self.liveRecordingChanged = liveRecordingChanged
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if resolvedSettings.livePhotoMovieDimensions.width > 0 {
            isRecordingLive = true
            liveRecordingChanged(true)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapture()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            processingError = error
        } else {
            photoData = photo.fileDataRepresentation()
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL,
                     resolvedSettings: AVCaptureResolvedPhotoSettings) {
        stopLiveRecording()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                     duration: CMTime, photoDisplayTime: CMTime,
                     resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error == nil {
            liveMovie = LivePhotoMovie(url: outputFileURL, photoDisplayTime: photoDisplayTime)
        } else {
            // Movie failed: the photo is kept as a normal photo.
            try? FileManager.default.removeItem(at: outputFileURL)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        stopLiveRecording()
        if let photoData, error == nil {
            completion(.success((photoData, liveMovie)))
        } else {
            if let liveMovie { try? FileManager.default.removeItem(at: liveMovie.url) }
            completion(.failure(error ?? processingError ?? CameraEngineError.captureFailed))
        }
    }

    private func stopLiveRecording() {
        guard isRecordingLive else { return }
        isRecordingLive = false
        liveRecordingChanged(false)
    }
}
