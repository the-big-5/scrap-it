import Foundation

enum AppTab: String {
    case home
    case profile
}

enum DeskCollectionKind: Hashable {
    case scrapbooks
    case rolls
}

enum AppRoute: Hashable {
    case createRollSetup
    case createRollFilter
    /// Host, before the roll starts: Edit Room → Edit Roll (change 081); then `.createRollFilter` in edit mode.
    case editRollSetup
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
        case .createRollSetup, .createRollFilter, .editRollSetup, .createRollLobby, .joinRoll, .captureSession:
            return true
        case .scrapbook, .editProfile, .rollReveal, .deskCollection:
            return false
        }
    }
}
