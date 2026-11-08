import Foundation

enum AppTab: String {
    case home
    case explore
    case profile
}

enum AppRoute: Hashable {
    case createRollSetup
    case createRollFilter
    case createRollLobby
    case joinRoll
    case captureSession
    case scrapbook(UUID)

    var isRollRoute: Bool {
        switch self {
        case .createRollSetup, .createRollFilter, .createRollLobby, .joinRoll, .captureSession:
            return true
        case .scrapbook:
            return false
        }
    }
}
