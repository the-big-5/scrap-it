import Foundation
import Observation

@Observable
final class WorkbenchViewModel {
    @ObservationIgnored private weak var navigator: (any Navigator)?
    @ObservationIgnored private let sessionStore: SessionStore

    var isCameraActive: Bool = false

    init(navigator: (any Navigator)? = nil, sessionStore: SessionStore = SessionStore()) {
        self.navigator = navigator
        self.sessionStore = sessionStore
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
        navigator?.push(.scrapbookGrid(scrapbook.id))
    }

    func openLatestScrapbook(from scrapbooks: [Scrapbook]) {
        if let latest = scrapbooks.first {
            openScrapbook(latest)
        }
    }
}
