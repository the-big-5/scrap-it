import Foundation

enum AppTab: String {
    case home
    case profile
}

enum AppRoute: Hashable {
    case createRollSetup
    case createRollFilter
    case createRollLobby
    case joinRoll
    case captureSession
    case scrapbook(UUID)
    case editProfile

    var isRollRoute: Bool {
        switch self {
        case .createRollSetup, .createRollFilter, .createRollLobby, .joinRoll, .captureSession:
            return true
        case .scrapbook, .editProfile:
            return false
        }
    }
}
