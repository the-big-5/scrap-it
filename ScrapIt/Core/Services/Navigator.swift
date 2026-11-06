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
    case scrapbookGrid(UUID)
}

/// Navigation contract used by feature ViewModels. Implemented by `AppRouter` in `App/`,
/// so features never import each other or the app shell.
protocol Navigator: AnyObject {
    var selectedTab: AppTab { get set }
    var path: [AppRoute] { get set }
}

extension Navigator {
    func push(_ route: AppRoute) {
        path.append(route)
    }

    func setStack(_ routes: [AppRoute]) {
        path = routes
    }

    func popToRoot() {
        path.removeAll()
    }
}
