import SwiftData
import SwiftUI

/// App shell: owns the router and shared store, builds each feature's ViewModel, and maps routes to screens.
struct MainTabView: View {
    @Query(sort: \Scrapbook.createdDate, order: .reverse) private var scrapbooks: [Scrapbook]

    let currentUser: UserProfile
    let onSignOut: () -> Void

    @State private var router: AppRouter
    @State private var rollViewModel: RollFlowViewModel
    @State private var workbenchViewModel: WorkbenchViewModel
    @State private var profileViewModel: ProfileViewModel
    @State private var scrapbookViewModel: ScrapbookViewModel

    init(currentUser: UserProfile, modelContext: ModelContext, onSignOut: @escaping () -> Void) {
        self.currentUser = currentUser
        self.onSignOut = onSignOut
        let router = AppRouter()
        let sessionStore = SessionStore(modelContext: modelContext)
        _router = State(initialValue: router)
        _rollViewModel = State(initialValue: RollFlowViewModel(modelContext: modelContext, navigator: router, sessionStore: sessionStore))
        _workbenchViewModel = State(initialValue: WorkbenchViewModel(navigator: router, sessionStore: sessionStore))
        _profileViewModel = State(initialValue: ProfileViewModel(currentUser: currentUser))
        _scrapbookViewModel = State(initialValue: ScrapbookViewModel(modelContext: modelContext, navigator: router, sessionStore: sessionStore))
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ZStack(alignment: .bottom) {
                Group {
                    switch router.selectedTab {
                    case .home:
                        WorkbenchView(
                            viewModel: workbenchViewModel,
                            scrapbooks: scrapbooks
                        )
                    case .explore:
                        ExploreView()
                    case .profile:
                        ProfileView(viewModel: profileViewModel, scrapbooksCount: scrapbooks.count, onSignOut: onSignOut)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if router.path.isEmpty && (!workbenchViewModel.isCameraActive || router.selectedTab != .home) {
                    FloatingTabBarView(selectedTab: $router.selectedTab)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: workbenchViewModel.isCameraActive)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .createRollSetup:
                    CreateRollSetupView(flowViewModel: rollViewModel)
                case .createRollFilter:
                    CreateRollFilterView(
                        currentUser: currentUser,
                        flowViewModel: rollViewModel
                    )
                case .createRollLobby:
                    CreateRollLobbyView(
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
                currentUser: currentUser
            )
        }
        // Restore scrapbooks after sign-in / on launch, and fill in friends' photos (change 012).
        .task {
            await rollViewModel.syncScrapbookArchive()
        }
        // iCloud roll invite opened by tap or AirDrop (change 011). Runs in its own Task: emptying the
        // inbox must not cancel the CloudKit calls (a `.task(id:)` on `pending` did, "Operation Cancelled").
        .onChange(of: IncomingShareInbox.shared.pending, initial: true) { _, pending in
            guard pending != nil, let metadata = IncomingShareInbox.shared.take() else { return }
            Task {
                await rollViewModel.acceptIncomingShare(metadata, currentUser: currentUser)
            }
        }
        // Removed by the host / roll deleted / invite could not be opened.
        .alert(
            rollViewModel.roomExitMessage ?? "",
            isPresented: Binding(
                get: { rollViewModel.roomExitMessage != nil },
                set: { if !$0 { rollViewModel.roomExitMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
    }
}
