import Foundation
import Observation
import SwiftData

@Observable
final class WorkbenchViewModel {
    private let modelContext: ModelContext
    @ObservationIgnored private weak var navigator: (any Navigator)?
    private let sessionStore: SessionStore

    var isCameraActive: Bool = false {
        didSet {
            navigator?.isTabBarHidden = isCameraActive
        }
    }

    /// Return transition phase when navigating back from camera (change 086).
    var cameraReturnPhase: CameraReturnPhase {
        navigator?.cameraReturnPhase ?? .idle
    }

    var cameraReturnAngle: Double {
        navigator?.cameraReturnAngle ?? 0.0
    }

    func animateCameraReturnToIdle() {
        navigator?.animateCameraReturnToIdle()
    }

    func finishCameraReturn() {
        navigator?.finishCameraReturn()
    }

    init(
        modelContext: ModelContext,
        navigator: (any Navigator)? = nil,
        sessionStore: SessionStore
    ) {
        self.modelContext = modelContext
        self.navigator = navigator
        self.sessionStore = sessionStore
    }

    var scrapbooks: [Scrapbook] {
        let descriptor = FetchDescriptor<Scrapbook>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func toggleCamera() {
        isCameraActive.toggle()
    }

    func dismissCamera() {
        isCameraActive = false
    }

    func startCreateRoll() {
        isCameraActive = false
        navigator?.setStack([.createRollSetup])
    }

    func startJoinRoll() {
        isCameraActive = false
        navigator?.setStack([.joinRoll])
    }

    func openTutorial() {
        // Stub for upcoming tutorial flow
    }

    func openScrapbook(_ scrapbook: Scrapbook) {
        sessionStore.activeScrapbook = scrapbook
        navigator?.push(.scrapbook(scrapbook.id))
    }

    func openLatestScrapbook() {
        if let latest = scrapbooks.first {
            openScrapbook(latest)
        }
    }
}
