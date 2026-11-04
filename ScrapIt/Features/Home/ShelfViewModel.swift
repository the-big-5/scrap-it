import Foundation
import Observation

@Observable
final class ShelfViewModel {
    @ObservationIgnored private weak var navigator: (any Navigator)?
    @ObservationIgnored private let sessionStore: SessionStore

    init(navigator: (any Navigator)? = nil, sessionStore: SessionStore = SessionStore()) {
        self.navigator = navigator
        self.sessionStore = sessionStore
    }

    func openCameraRoll() {
        navigator?.setStack([.cameraRollMenu])
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
