import Foundation

/// Navigation contract used by feature ViewModels. Implemented by `AppRouter` in `App/Navigation/`,
/// so features never import each other or the app shell.
protocol Navigator: AnyObject {
    var selectedTab: AppTab { get set }
    var path: [AppRoute] { get set }
    var isTabBarHidden: Bool { get set }
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
