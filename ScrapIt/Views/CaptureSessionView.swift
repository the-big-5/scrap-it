import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Observation
import SwiftData
import SwiftUI
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
        withAnimation(.easeOut(duration: 0.08)) {
            shutterFlashOpacity = 0.85
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeIn(duration: 0.18)) {
                shutterFlashOpacity = 0.0
            }
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

// MARK: - Live AVFoundation Video Preview Layer

#if canImport(UIKit)
struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
#endif

// MARK: - Capture Session Screen (Figma node 708:4941)

struct CaptureSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var camera = CameraController()

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    private var session: CaptureSession? {
        flowViewModel.activeSession
    }

    private var isHost: Bool {
        session?.hostUserID == currentUser.appleUserID
    }

    private var remainingShotsText: String {
        let remaining = session?.remainingSlots ?? 36
        return String(format: "%02d", remaining)
    }

    private var totalShotsText: String {
        "/\(session?.rollSize ?? 36)"
    }

    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width
            ZStack {
                Color.black.ignoresSafeArea()

                if isPortrait {
                    // Render the landscape camera body rotated 90° so it fills portrait phones naturally
                    // while also supporting true landscape rotation seamlessly
                    cameraBodyContent
                        .frame(width: geo.size.height, height: geo.size.width)
                        .rotationEffect(.degrees(90))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                } else {
                    cameraBodyContent
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            camera.startSession()
            flowViewModel.cloudService.updateQueuedCount(modelContext: modelContext)
        }
        .onDisappear {
            camera.stopSession()
        }
        .alert("Roll Finished", isPresented: $flowViewModel.showLastSlotRaceAlert) {
            Button("Open Scrapbook") {
                flowViewModel.finalizeSessionAndOpenScrapbook(modelContext: modelContext)
            }
        } message: {
            Text(flowViewModel.lastSlotRaceMessage)
        }
    }

    private var cameraBodyContent: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Top Black Camera Deck (Flash, Live, Viewfinder Housing, Advance, Shots Counter, Zoom Wheel, Shutter)
                topCameraDeck
                    .frame(height: 102)

                // Green Camera Body (Strap lugs, Viewfinder Screen, Tally dot + Flip + Grid, Right Grip)
                lowerGreenBody
                    .frame(maxHeight: .infinity)
            }

            // Optical viewfinder housing straddling the top deck and green body per Figma node 708:4941
            opticalViewfinderHousing
                .offset(x: -96, y: 8)
        }
    }

    // MARK: - Top Black Deck

    private var topCameraDeck: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.15), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 14) {
                // Flash toggle pill
                Button {
                    camera.cycleFlash()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(camera.flashChoice.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(ScrapTheme.cameraGold)
                    .frame(width: 96, height: 48)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.19))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                // LIVE toggle pill
                Button {
                    camera.isLivePhotoEnabled.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "livephoto")
                            .font(.system(size: 14, weight: .bold))
                        Text("LIVE")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(
                        camera.isLivePhotoEnabled
                            ? ScrapTheme.cameraGold
                            : Color.white.opacity(0.45)
                    )
                    .frame(width: 96, height: 48)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.19))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                // Space reserved for optical viewfinder housing
                Spacer()
                    .frame(width: 148)

                // Silver advance / host controls button (▶◀)
                Menu {
                    if isHost {
                        Button(role: .destructive) {
                            flowViewModel.endSessionManuallyByHost(
                                currentUser: currentUser,
                                modelContext: modelContext
                            )
                        } label: {
                            Label("End Roll Now (Host)", systemImage: "stop.circle.fill")
                        }
                    }
                    Button {
                        if let currentHost = session?.hostUserID {
                            flowViewModel.handleHostDisconnect(
                                disconnectedHostID: currentHost,
                                modelContext: modelContext
                            )
                        }
                    } label: {
                        Label("Simulate Host Disconnect Handover", systemImage: "person.badge.key.fill")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                            .rotationEffect(.degrees(180))
                    }
                    .foregroundStyle(Color(white: 0.55))
                    .frame(width: 68, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.90), Color(white: 0.78)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                }

                // Shots Counter (09 /36 SHOTS)
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(remainingShotsText)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(ScrapTheme.cameraGold)
                        Text(totalShotsText)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .frame(width: 78, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(white: 0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )

                    Text("SHOTS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                // Knurled Zoom Wheel (ZOOM 1.0x)
                Button {
                    camera.cycleZoom()
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(white: 0.16),
                                            Color(white: 0.36),
                                            Color(white: 0.16)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 172, height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black, lineWidth: 1.5)
                                )

                            HStack(spacing: 12) {
                                ForEach(0..<10, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.black.opacity(0.75))
                                        .frame(width: 2.2, height: 34)
                                }
                            }
                        }

                        Text(String(format: "ZOOM %.1fx", camera.zoomFactor))
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.0)
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                }
                .buttonStyle(.plain)

                // Metallic Circular Shutter Button
                Button {
                    Task {
                        let imageData = await camera.captureShot(
                            filter: session?.filter ?? .colorPrint200,
                            rollName: session?.name ?? "Roll"
                        )
                        await flowViewModel.recordCapturedShot(
                            imageData: imageData,
                            livePhotoMovieData: camera.isLivePhotoEnabled ? Data("live".utf8) : nil,
                            currentUser: currentUser,
                            modelContext: modelContext
                        )
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.08))
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white,
                                        Color(white: 0.72),
                                        Color(white: 0.42)
                                    ],
                                    center: .center,
                                    startRadius: 4,
                                    endRadius: 32
                                )
                            )
                            .frame(width: 56, height: 56)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }
    }

    private var opticalViewfinderHousing: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.18), Color(white: 0.09)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 142, height: 112)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 4)

            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.04))
                .frame(width: 92, height: 68)

            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.10),
                            Color(red: 0.16, green: 0.20, blue: 0.20),
                            Color(white: 0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 52, height: 34)
        }
    }

    // MARK: - Lower Green Camera Body

    private var lowerGreenBody: some View {
        ZStack {
            ScrapTheme.cameraGreen

            HStack(spacing: 18) {
                // Left strap lugs
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color(white: 0.10))
                        .frame(width: 14, height: 58)
                    Capsule()
                        .fill(Color(white: 0.10))
                        .frame(width: 14, height: 58)
                }
                .padding(.leading, 18)

                // Main Viewfinder Screen (No other users' photos shown — only own viewfinder)
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(white: 0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(white: 0.12), lineWidth: 8)
                        )

                    #if canImport(UIKit)
                    if camera.isCameraAuthorized && camera.captureSession.isRunning {
                        CameraPreviewLayerView(session: camera.captureSession)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(6)
                    }
                    #endif

                    // Rule-of-thirds Grid Overlay when GRID button is active
                    if camera.isGridVisible {
                        CameraGridOverlay()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(6)
                    }

                    // Shutter flash feedback
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(camera.shutterFlashOpacity))
                        .padding(6)
                        .allowsHitTesting(false)

                    // Viewfinder HUD overlays (LIVE badge, presence & offline indicator, zoom badge)
                    VStack {
                        HStack {
                            if camera.isLivePhotoEnabled {
                                Text("LIVE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.black.opacity(0.65))
                                    )
                            }

                            Spacer()

                            // Live presence count & offline queue status
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 10))
                                Text("\(session?.participantIDs.count ?? 1)")
                                    .font(.system(size: 11, weight: .semibold))

                                if !flowViewModel.cloudService.isOnline || flowViewModel.cloudService.queuedOfflineCount > 0 {
                                    Text("• \(flowViewModel.cloudService.queuedOfflineCount) queued")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(ScrapTheme.cameraGold)
                                }
                            }
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.65))
                            )
                        }

                        if let banner = flowViewModel.hostHandoverBanner {
                            Text(banner)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ScrapTheme.cameraGold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.75)))
                        }

                        Spacer()

                        HStack {
                            if isHost {
                                Button {
                                    flowViewModel.endSessionManuallyByHost(
                                        currentUser: currentUser,
                                        modelContext: modelContext
                                    )
                                } label: {
                                    Text("END ROLL")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(0.6)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(ScrapTheme.indicatorRed.opacity(0.85))
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            Text(String(format: "%.1fx", camera.zoomFactor))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ScrapTheme.cameraGold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black.opacity(0.65))
                                )
                        }
                    }
                    .padding(18)
                }
                .frame(maxWidth: 490)
                .padding(.vertical, 16)

                // Right Column Controls: Red tally dot, FLIP button, GRID button
                VStack(spacing: 18) {
                    Circle()
                        .fill(ScrapTheme.indicatorRed)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.85), lineWidth: 2.5)
                        )
                        .padding(.bottom, 4)

                    // FLIP camera button
                    Button {
                        camera.toggleCameraPosition()
                    } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.10))
                                    .frame(width: 54, height: 54)
                                    .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(ScrapTheme.cameraGold)
                            }
                            Text("FLIP")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    // GRID overlay button
                    Button {
                        camera.isGridVisible.toggle()
                    } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.10))
                                    .frame(width: 54, height: 54)
                                    .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
                                Image(systemName: "squareshape.split.3x3")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(
                                        camera.isGridVisible
                                            ? ScrapTheme.cameraGold
                                            : ScrapTheme.cameraGold.opacity(0.65)
                                    )
                            }
                            Text("GRID")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)

                // Molded Right Hand Grip
                RoundedRectangle(cornerRadius: 28)
                    .fill(ScrapTheme.cameraDarkGreen)
                    .frame(width: 190)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.black.opacity(0.25), lineWidth: 2)
                    )
                    .padding(.vertical, 14)
                    .padding(.trailing, -24)
            }
        }
    }
}

struct CameraGridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
