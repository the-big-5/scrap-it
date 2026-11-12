import Foundation
import Observation

@Observable
final class AppRouter: Navigator {
    var selectedTab: AppTab = .home
    var isTabBarHidden: Bool = false
    var path: [AppRoute] = []
    var cameraReturnPhase: CameraReturnPhase = .idle
    var cameraReturnAngle: Double = 0.0
    var cameraIntroPhase: CameraIntroPhase = .idle
    var cameraIntroFilter: RollFilter = .colorPrint200
    var isFadingToReveal: Bool = false

    var shouldShowTabBar: Bool {
        path.isEmpty && (!isTabBarHidden || selectedTab != .home) && cameraReturnPhase == .idle && cameraIntroPhase == .idle
    }

    /// Extracts a valid 6-character join code from deep-link URLs (e.g. `scrapit://join?code=N4B13L`).
    static func parseJoinCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value?
                  .trimmingCharacters(in: .whitespacesAndNewlines)
                  .uppercased(),
              code.count == 6
        else {
            return nil
        }
        return code
    }
}
