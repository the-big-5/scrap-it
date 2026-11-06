import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

enum CameraFlashChoice: String, CaseIterable {
    case auto = "AUTO"
    case on = "ON"
    case off = "OFF"
}

@Observable
final class CameraController: NSObject {
    var flashChoice: CameraFlashChoice = .auto
    var isLivePhotoEnabled: Bool = true
    var isGridVisible: Bool = false
    var isUsingFrontCamera: Bool = false
    var zoomFactor: CGFloat = 1.0
    var isCameraAuthorized: Bool = false
    var isCapturing: Bool = false
    var shutterFlashOpacity: Double = 0.0

    private(set) var zoomCapabilities: ZoomCapabilities = .none

    let captureSession = AVCaptureSession()

    var isPreviewReady: Bool {
        isCameraAuthorized && captureSession.isRunning
    }

    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var continuation: CheckedContinuation<Data, Never>?
    private var shotSequenceNumber: Int = 0

    private var cameraPicker: AnyObject?

    var cameraOptionZooms: [CGFloat] {
        zoomCapabilities.presets.isEmpty ? [0.5, 1.0, 2.0] : zoomCapabilities.presets
    }

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(sessionDidStartRunning),
            name: AVCaptureSession.didStartRunningNotification,
            object: captureSession
        )
        center.addObserver(
            self,
            selector: #selector(sessionDidStopRunning),
            name: AVCaptureSession.didStopRunningNotification,
            object: captureSession
        )
    }

    @objc private func sessionDidStartRunning(_ notification: Notification) {
        Task { @MainActor in
            if #available(iOS 18.0, *) {
                self.updateCameraControls()
            }
        }
    }

    @objc private func sessionDidStopRunning(_ notification: Notification) {
        // Handle session stop if needed
    }

    func startSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isCameraAuthorized = true
            configureSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isCameraAuthorized = granted
                    if granted {
                        self.configureSessionIfNeeded()
                    }
                }
            }
        default:
            isCameraAuthorized = false
        }
    }

    func stopSession() {
        guard captureSession.isRunning else { return }
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }

    private static func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .front {
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        return discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private static func computeZoomCapabilities(for device: AVCaptureDevice) -> ZoomCapabilities {
        guard device.position == .back else { return .none }
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0.doubleValue) }
        let hasUltraWide = device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera
        let secondaryNative = device.activeFormat.secondaryNativeResolutionZoomFactors.map { CGFloat($0) }
        return ZoomCapabilities.make(
            hasUltraWide: hasUltraWide,
            switchOverFactors: switchOvers,
            secondaryNativeFactors: secondaryNative,
            minDeviceFactor: device.minAvailableVideoZoomFactor,
            maxDeviceFactor: device.maxAvailableVideoZoomFactor
        )
    }

    private func configureSessionIfNeeded() {
        guard !captureSession.isRunning else { return }
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // Remove existing inputs
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }

        let position: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        if let device = Self.bestDevice(for: position),
           let input = try? AVCaptureDeviceInput(device: device),
           captureSession.canAddInput(input) {
            captureSession.addInput(input)
            currentDevice = device
            if position == .back {
                zoomCapabilities = Self.computeZoomCapabilities(for: device)
            } else {
                zoomCapabilities = .none
            }
        }

        if captureSession.outputs.isEmpty && captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        captureSession.commitConfiguration()

        if #available(iOS 18.0, *) {
            updateCameraControls()
        }

        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session.startRunning()
            Task { @MainActor [weak self] in
                guard let self else { return }
                if #available(iOS 18.0, *) {
                    self.updateCameraControls()
                }
            }
        }
    }

    func toggleCameraPosition() {
        isUsingFrontCamera.toggle()
        zoomFactor = 1.0
        if captureSession.isRunning {
            let session = captureSession
            session.stopRunning()
        }
        configureSessionIfNeeded()
    }

    func setZoomFactor(_ factor: CGFloat, ramp: Bool = true) {
        guard !isUsingFrontCamera else {
            zoomFactor = 1.0
            return
        }
        let clamped = zoomCapabilities.isZoomable ? zoomCapabilities.clamped(factor) : factor
        zoomFactor = clamped
        #if os(iOS)
        if let device = currentDevice {
            let deviceFactor = zoomCapabilities.isZoomable
                ? zoomCapabilities.deviceFactor(forDisplayZoom: clamped)
                : clamped
            let targetFactor = min(max(deviceFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            do {
                try device.lockForConfiguration()
                if ramp {
                    device.ramp(toVideoZoomFactor: targetFactor, withRate: 4)
                } else {
                    if device.isRampingVideoZoom {
                        device.cancelVideoZoomRamp()
                    }
                    device.videoZoomFactor = targetFactor
                }
                device.unlockForConfiguration()
            } catch {}
        }
        if #available(iOS 18.0, *) {
            updateCameraControlSelection()
        }
        #endif
    }

    func cycleZoom() {
        let presets = zoomCapabilities.presets.isEmpty ? [0.5, 1.0, 2.0] : zoomCapabilities.presets
        let next = presets.first { $0 > zoomFactor + 0.05 } ?? presets.first ?? 1.0
        setZoomFactor(next, ramp: true)
    }

    func cycleFlash() {
        let all = CameraFlashChoice.allCases
        if let idx = all.firstIndex(of: flashChoice) {
            flashChoice = all[(idx + 1) % all.count]
        }
    }

    // MARK: - iOS 18 Camera Control Integration

    @available(iOS 18.0, *)
    func updateCameraControls() {
        guard captureSession.supportsControls else { return }
        captureSession.setControlsDelegate(self, queue: .main)
        captureSession.beginConfiguration()
        for control in captureSession.controls {
            captureSession.removeControl(control)
        }
        cameraPicker = nil

        // Dedicated System Zoom Slider for direct hardware Camera Control zoom swiping
        if let device = currentDevice, !isUsingFrontCamera {
            let zoomSlider = AVCaptureSystemZoomSlider(device: device) { [weak self] newFactor in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let displayZoom = self.zoomCapabilities.isZoomable
                        ? self.zoomCapabilities.displayZoom(forDeviceFactor: newFactor)
                        : newFactor
                    self.zoomFactor = displayZoom
                }
            }
            if captureSession.canAddControl(zoomSlider) {
                captureSession.addControl(zoomSlider)
            }
        }

        // Discrete Lens Picker for stepped jumping (Front · 0.5× · 1× · 2×)
        let options = cameraOptionZooms
        let titles = ["Front"] + options.map { ZoomCapabilities.label(for: $0) }
        let picker = AVCaptureIndexPicker("Camera", symbolName: "camera", localizedIndexTitles: titles)
        picker.setActionQueue(.main) { [weak self] index in
            guard let self else { return }
            self.handleCameraControlSelection(index)
        }
        if captureSession.canAddControl(picker) {
            captureSession.addControl(picker)
            cameraPicker = picker
            updateCameraControlSelection()
        }
        captureSession.commitConfiguration()
    }

    @available(iOS 18.0, *)
    private func updateCameraControlSelection() {
        guard let picker = cameraPicker as? AVCaptureIndexPicker else { return }
        let index: Int
        if isUsingFrontCamera {
            index = 0
        } else {
            let active = zoomCapabilities.activePreset(for: zoomFactor) ?? 1.0
            index = (cameraOptionZooms.firstIndex(of: active) ?? 0) + 1
        }
        if picker.selectedIndex != index {
            picker.selectedIndex = index
        }
    }

    private func handleCameraControlSelection(_ index: Int) {
        if index == 0 {
            if !isUsingFrontCamera {
                toggleCameraPosition()
            }
            return
        }
        let options = cameraOptionZooms
        guard options.indices.contains(index - 1) else { return }
        let targetZoom = options[index - 1]
        if isUsingFrontCamera {
            toggleCameraPosition()
        }
        setZoomFactor(targetZoom, ramp: true)
    }

    // MARK: - Photo Capture

    func captureShot(filter: RollFilter, rollName: String) async -> Data {
        shotSequenceNumber += 1
        shutterFlashOpacity = 0.85
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            shutterFlashOpacity = 0.0
        }

        if captureSession.isRunning && !captureSession.inputs.isEmpty {
            let rawData = await withCheckedContinuation { (cont: CheckedContinuation<Data, Never>) in
                self.continuation = cont
                let settings = AVCapturePhotoSettings()
                if self.photoOutput.supportedFlashModes.contains(.auto) {
                    switch self.flashChoice {
                    case .auto: settings.flashMode = .auto
                    case .on: settings.flashMode = .on
                    case .off: settings.flashMode = .off
                    }
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
            return Self.applyFilmFilter(to: rawData, filter: filter, shotIndex: shotSequenceNumber, rollName: rollName)
        } else {
            return Self.generateFilmFrameData(
                filter: filter,
                shotIndex: shotSequenceNumber,
                rollName: rollName,
                isLivePhoto: isLivePhotoEnabled
            )
        }
    }

    static func applyFilmFilter(
        to imageData: Data,
        filter: RollFilter,
        shotIndex: Int,
        rollName: String
    ) -> Data {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: imageData),
              let ciInput = CIImage(image: uiImage) else {
            return generateFilmFrameData(filter: filter, shotIndex: shotIndex, rollName: rollName, isLivePhoto: false)
        }
        let context = CIContext()
        let outputCI: CIImage
        switch filter {
        case .cinematicBW400:
            let noir = CIFilter.photoEffectNoir()
            noir.inputImage = ciInput
            outputCI = noir.outputImage ?? ciInput
        case .colorPrint200:
            let chrome = CIFilter.photoEffectChrome()
            chrome.inputImage = ciInput
            outputCI = chrome.outputImage ?? ciInput
        }
        if let cgImage = context.createCGImage(outputCI, from: outputCI.extent) {
            let filtered = UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: uiImage.imageOrientation)
            return filtered.jpegData(compressionQuality: 0.85) ?? imageData
        }
        #endif
        return imageData
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

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        let data = photo.fileDataRepresentation() ?? Data()
        Task { @MainActor in
            self.continuation?.resume(returning: data)
            self.continuation = nil
        }
    }
}

extension CameraController: AVCaptureSessionControlsDelegate {
    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {}
    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {}
}
