import SwiftData
import SwiftUI

/// App shell: owns the router and shared store, builds each feature's ViewModel, and maps routes to screens.
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Scrapbook.createdDate, order: .reverse) private var scrapbooks: [Scrapbook]

    let currentUser: UserProfile
    let onSignOut: () -> Void

    @State private var router: AppRouter
    @State private var rollViewModel: RollFlowViewModel
    @State private var shelfViewModel: ShelfViewModel
    @State private var profileViewModel: ProfileViewModel
    @State private var scrapbookViewModel: ScrapbookViewModel

    init(currentUser: UserProfile, onSignOut: @escaping () -> Void) {
        self.currentUser = currentUser
        self.onSignOut = onSignOut
        let router = AppRouter()
        let sessionStore = SessionStore()
        _router = State(initialValue: router)
        _rollViewModel = State(initialValue: RollFlowViewModel(navigator: router, sessionStore: sessionStore))
        _shelfViewModel = State(initialValue: ShelfViewModel(navigator: router, sessionStore: sessionStore))
        _profileViewModel = State(initialValue: ProfileViewModel(currentUser: currentUser))
        _scrapbookViewModel = State(initialValue: ScrapbookViewModel(navigator: router, sessionStore: sessionStore))
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ZStack(alignment: .bottom) {
                ScrapTheme.creamBackground
                    .ignoresSafeArea()

                Group {
                    switch router.selectedTab {
                    case .home:
                        ShelfView(
                            scrapbooks: scrapbooks,
                            onTapCamera: {
                                shelfViewModel.openCameraRoll()
                            },
                            onTapScrapbook: { _ in
                                shelfViewModel.openLatestScrapbook(from: scrapbooks)
                            }
                        )
                    case .profile:
                        ProfileView(viewModel: profileViewModel, scrapbooksCount: scrapbooks.count, onSignOut: onSignOut)
                    }
                }

                FloatingHomeProfileTabBar(selectedTab: $router.selectedTab)
                    .padding(.bottom, 16)
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .cameraRollMenu:
                    CameraRollMenuView(flowViewModel: rollViewModel)
                case .createStep1NameAndShots:
                    CreateRollStep1View(flowViewModel: rollViewModel)
                case .createStep2ChooseFilter:
                    CreateRollStep2FilterView(
                        currentUser: currentUser,
                        flowViewModel: rollViewModel
                    )
                case .createStep3ShareRoom:
                    CreateRollStep3ShareRoomView(
                        currentUser: currentUser,
                        flowViewModel: rollViewModel
                    )
                case .joinRoll:
                    JoinRollView(
                        currentUser: currentUser,
                        flowViewModel: rollViewModel
                    )
                case .captureSession:
                    CaptureSessionView(
                        currentUser: currentUser,
                        flowViewModel: rollViewModel
                    )
                case .scrapbookGrid(let scrapbookID):
                    ScrapbookGridView(
                        scrapbookID: scrapbookID,
                        currentUser: currentUser,
                        viewModel: scrapbookViewModel
                    )
                }
            }
        }
        .onOpenURL { url in
            rollViewModel.handleIncomingURL(
                url,
                currentUser: currentUser,
                modelContext: modelContext
            )
        }
    }
}
