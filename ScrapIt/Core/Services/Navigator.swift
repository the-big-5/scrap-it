import Foundation

/// Phases for the two-step transition returning from camera to workbench (change 086).
enum CameraReturnPhase: Equatable, Sendable {
    case idle
    case zoomedIn
    case animatingToIdle
}

/// Navigation contract used by feature ViewModels. Implemented by `AppRouter` in `App/Navigation/`,
/// so features never import each other or the app shell.
protocol Navigator: AnyObject {
    var selectedTab: AppTab { get set }
    var path: [AppRoute] { get set }
    var isTabBarHidden: Bool { get set }
    var cameraReturnPhase: CameraReturnPhase { get set }
    var cameraReturnAngle: Double { get set }
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

    func beginCameraReturn(angle: Double) {
        cameraReturnAngle = angle
        cameraReturnPhase = .zoomedIn
        isTabBarHidden = true
    }

    func animateCameraReturnToIdle() {
        cameraReturnPhase = .animatingToIdle
    }

    func finishCameraReturn() {
        cameraReturnPhase = .idle
        isTabBarHidden = false
    }
}
