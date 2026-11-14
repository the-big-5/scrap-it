import Foundation
import Observation
import TipKit

/// One tip of the camera tutorial (change 152), shown by TipKit's inline tip view. Tips are never invalidated, so
/// they come back each time the tutorial opens; the tutorial picks which one shows.
struct CameraTutorialTip: Tip {
    let control: CameraControl
    let titleText: String
    let messageText: String

    var id: String { "cameraTutorial.\(titleText)" }
    var title: Text { Text(titleText) }
    var message: Text? { Text(messageText) }
}

/// The camera tutorial after "Let's Try It" (change 152): five tips in order, the "Try it Out" card, two practice
/// shots on the real camera (kept on this phone only, `TutorialPhotoStore`), then the finished card.
@MainActor
@Observable
final class CameraTutorialViewModel {
    enum Step: Equatable {
        case tip(Int)
        case tryItOut
        case shooting
        case finished
    }

    static let totalShots = 2

    static let tips: [CameraTutorialTip] = [
        CameraTutorialTip(control: .shotsLeft, titleText: "Shots Remaining",
                          messageText: "Keep track of how many photos you can still take before your roll is complete."),
        CameraTutorialTip(control: .zoom, titleText: "Zoom",
                          messageText: "Drag the dial to zoom in and out."),
        CameraTutorialTip(control: .flash, titleText: "Flash",
                          messageText: "Tap to turn the flash on or off. Turn it on for darker scenes."),
        CameraTutorialTip(control: .flip, titleText: "Flip",
                          messageText: "Tap to switch between the front and back camera."),
        CameraTutorialTip(control: .shutter, titleText: "Take a Photo",
                          messageText: "Press the shutter to snap a photo. Every shot counts, so make it a good one."),
    ]

    let camera: CameraController
    private let photoStore: TutorialPhotoStore
    private(set) var step: Step = .tip(0)
    private(set) var shotsRemaining = CameraTutorialViewModel.totalShots
    private var isTakingShot = false

    init(camera: CameraController = CameraController(), photoStore: TutorialPhotoStore = TutorialPhotoStore()) {
        self.camera = camera
        self.photoStore = photoStore
        photoStore.clear()
    }

    var currentTip: CameraTutorialTip? {
        guard case let .tip(index) = step else { return nil }
        return Self.tips[index]
    }

    /// The camera's controls only react once the tips and the "Try it Out" card are done.
    var areControlsEnabled: Bool { step == .shooting }

    /// A tap anywhere or X on a tip, or a tap on the "Try it Out" card.
    func advance() {
        switch step {
        case let .tip(index):
            step = index + 1 < Self.tips.count ? .tip(index + 1) : .tryItOut
        case .tryItOut:
            step = .shooting
        case .shooting, .finished:
            break
        }
    }

    /// One practice shot: the dial counts down at once; the photo is kept (not without camera access). After the
    /// last one, the finished card.
    func shutterTapped() async {
        guard step == .shooting, shotsRemaining > 0, !isTakingShot, camera.canCapture else { return }
        isTakingShot = true
        defer { isTakingShot = false }
        shotsRemaining -= 1
        let index = Self.totalShots - shotsRemaining
        let shot = await camera.captureShot(filter: .colorPrint200, rollName: "Tutorial")
        if camera.isCameraAuthorized {
            photoStore.save(shot.imageData, index: index)
        }
        if shotsRemaining == 0 {
            step = .finished
        }
    }
}

/// The tutorial's practice photos (change 152): on this phone only, in the app's temporary folder, replaced by
/// the next tutorial; kept for the scrapbook tutorial later. No roll, no SwiftData, no upload.
struct TutorialPhotoStore {
    var directory = FileManager.default.temporaryDirectory.appending(path: "CameraTutorial", directoryHint: .isDirectory)

    func clear() {
        try? FileManager.default.removeItem(at: directory)
    }

    func save(_ data: Data, index: Int) {
        guard !data.isEmpty else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appending(path: "Shot\(index).jpg"))
    }

    var photoURLs: [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
