import Observation

@Observable
final class AppRouter: Navigator {
    var selectedTab: AppTab = .home
    var path: [AppRoute] = []
}
