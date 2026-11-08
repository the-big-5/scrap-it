import SwiftData
import SwiftUI

/// Lightweight app shell: switches root tabs, renders the floating tab bar, and maps routes to feature screens.
/// Does not run `@Query` or retain feature ViewModels in `@State`.
struct MainShellView: View {
    let currentUser: UserProfile
    let modelContext: ModelContext
    let onSignOut: () -> Void

    @State private var router = AppRouter()
    @State private var sessionStore: SessionStore
    @State private var rollViewModel: RollFlowViewModel?
    /// Restores scrapbooks after sign-in / on launch (change 012).
    @State private var archiveSync: ScrapbookArchiveSync

    init(currentUser: UserProfile, modelContext: ModelContext, onSignOut: @escaping () -> Void) {
        self.currentUser = currentUser
        self.modelContext = modelContext
        self.onSignOut = onSignOut
        _sessionStore = State(initialValue: SessionStore(modelContext: modelContext))
        _archiveSync = State(initialValue: ScrapbookArchiveSync(
            modelContext: modelContext,
            roomService: CloudKitRollRoomService()
        ))
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ZStack(alignment: .bottom) {
                Group {
                    switch router.selectedTab {
                    case .home:
                        WorkbenchView(
                            modelContext: modelContext,
                            navigator: router,
                            sessionStore: sessionStore
                        )
                    case .explore:
                        ExploreView()
                    case .profile:
                        ProfileView(
                            modelContext: modelContext,
                            currentUser: currentUser,
                            navigator: router,
                            onSignOut: onSignOut
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if router.shouldShowTabBar {
                    FloatingTabBarView(selectedTab: $router.selectedTab)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: router.isTabBarHidden)
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
        }
        .onChange(of: router.path) { _, newPath in
            if !newPath.contains(where: \.isRollRoute) {
                rollViewModel = nil
            }
        }
        .task {
            await archiveSync.run()
        }
        // iCloud roll invite opened by tap or AirDrop (change 011). Runs in its own Task: emptying the
        // inbox must not cancel the CloudKit calls (a `.task(id:)` on `pending` did, "Operation Cancelled").
        .onChange(of: IncomingShareInbox.shared.pending, initial: true) { _, pending in
            guard pending != nil, let metadata = IncomingShareInbox.shared.take() else { return }
            let vm = activeRollViewModel()
            Task {
                await vm.acceptIncomingShare(metadata, currentUser: currentUser)
            }
        }
        // Removed by the host / roll deleted / invite could not be opened (change 011).
        .alert(
            sessionStore.roomExitMessage ?? "",
            isPresented: Binding(
                get: { sessionStore.roomExitMessage != nil },
                set: { if !$0 { sessionStore.roomExitMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
        .onOpenURL { url in
            if let code = AppRouter.parseJoinCode(from: url) {
                router.selectedTab = .home
                let vm = activeRollViewModel()
                Task {
                    await vm.joinRollWithCode(code: code, currentUser: currentUser)
                }
            }
        }
    }

    private func activeRollViewModel() -> RollFlowViewModel {
        if let existing = rollViewModel {
            return existing
        }
        let newVM = RollFlowViewModel(
            modelContext: modelContext,
            navigator: router,
            sessionStore: sessionStore
        )
        rollViewModel = newVM
        return newVM
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .createRollSetup:
            CreateRollSetupView(flowViewModel: activeRollViewModel())
        case .createRollFilter:
            CreateRollFilterView(currentUser: currentUser, flowViewModel: activeRollViewModel())
        case .createRollLobby:
            CreateRollLobbyView(currentUser: currentUser, flowViewModel: activeRollViewModel())
        case .joinRoll:
            JoinRollView(currentUser: currentUser, flowViewModel: activeRollViewModel())
        case .captureSession:
            CaptureSessionView(currentUser: currentUser, flowViewModel: activeRollViewModel())
        case .scrapbook(let scrapbookID):
            ScrapbookEditorView(viewModel: ScrapbookViewModel(
                modelContext: modelContext,
                navigator: router,
                sessionStore: sessionStore,
                scrapbookID: scrapbookID
            ))
        }
    }
}
