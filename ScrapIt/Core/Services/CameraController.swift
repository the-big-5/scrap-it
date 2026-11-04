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

    let captureSession = AVCaptureSession()

    var isPreviewReady: Bool {
        isCameraAuthorized && captureSession.isRunning
    }

    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var continuation: CheckedContinuation<Data, Never>?
    private var shotSequenceNumber: Int = 0

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

    private func configureSessionIfNeeded() {
        guard !captureSession.isRunning else { return }
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // Remove existing inputs
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }

        let position: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device),
           captureSession.canAddInput(input) {
            captureSession.addInput(input)
            currentDevice = device
        }

        if captureSession.outputs.isEmpty && captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        captureSession.commitConfiguration()

        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
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

    func cycleZoom() {
        let steps: [CGFloat] = [1.0, 1.5, 2.0, 3.0]
        if let idx = steps.firstIndex(of: zoomFactor) {
            zoomFactor = steps[(idx + 1) % steps.count]
        } else {
            zoomFactor = 1.0
        }
        #if os(iOS)
        if let device = currentDevice {
            do {
                try device.lockForConfiguration()
                let clamped = min( max(1.0, zoomFactor), device.activeFormat.videoMaxZoomFactor )
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {}
        }
        #endif
    }

    func cycleFlash() {
        let all = CameraFlashChoice.allCases
        if let idx = all.firstIndex(of: flashChoice) {
            flashChoice = all[(idx + 1) % all.count]
        }
    }

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
