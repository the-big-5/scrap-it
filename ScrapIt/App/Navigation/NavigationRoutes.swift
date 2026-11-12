import Foundation

enum AppTab: String {
    case home
    case profile
}

enum DeskCollectionKind: Hashable {
    case scrapbooks
}

enum AppRoute: Hashable {
    case createRollSetup
    case createRollFilter
    case createRollLobby
    case joinRoll
    case captureSession
    case scrapbook(UUID)
    case editProfile
    /// Shown once after End Roll (change 021).
    case rollReveal(UUID)
    /// Composable desk collection shelf pushed from interactive workbench items (change 104).
    case deskCollection(DeskCollectionKind)

    var isRollRoute: Bool {
        switch self {
        case .createRollSetup, .createRollFilter, .createRollLobby, .joinRoll, .captureSession:
            return true
        case .scrapbook, .editProfile, .rollReveal, .deskCollection:
            return false
        }
    }
}
