import SwiftData
import SwiftUI

/// Lightweight app shell: switches root tabs, renders the floating tab bar, and maps routes to feature screens.
/// Does not run `@Query` or retain feature ViewModels in `@State`.
struct MainShellView: View {
    let currentUser: UserProfile
    let modelContext: ModelContext
    let onSignOut: () -> Void

    @State private var router: AppRouter
    @State private var sessionStore: SessionStore
    @State private var rollViewModel: RollFlowViewModel?
    @State private var workbenchViewModel: WorkbenchViewModel
    @State private var profileViewModel: ProfileViewModel
    /// Restores scrapbooks after sign-in / on launch (change 012).
    @State private var archiveSync: ScrapbookArchiveSync

    init(currentUser: UserProfile, modelContext: ModelContext, onSignOut: @escaping () -> Void) {
        self.currentUser = currentUser
        self.modelContext = modelContext
        self.onSignOut = onSignOut
        let appRouter = AppRouter()
        let store = SessionStore(modelContext: modelContext)
        let roomService = CloudKitRollRoomService()
        _router = State(initialValue: appRouter)
        _sessionStore = State(initialValue: store)
        _workbenchViewModel = State(initialValue: WorkbenchViewModel(
            modelContext: modelContext,
            navigator: appRouter,
            sessionStore: store,
            currentUser: currentUser,
            roomService: roomService
        ))
        _profileViewModel = State(initialValue: ProfileViewModel(
            modelContext: modelContext,
            currentUser: currentUser,
            navigator: appRouter,
            onSignOut: onSignOut
        ))
        _archiveSync = State(initialValue: ScrapbookArchiveSync(
            modelContext: modelContext,
            roomService: roomService
        ))
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            TabView(selection: $router.selectedTab) {
                Tab("Craft", systemImage: "camera.fill", value: AppTab.home) {
                    WorkbenchView(viewModel: workbenchViewModel)
                        .toolbarVisibility(router.shouldShowTabBar ? .visible : .hidden, for: .tabBar)
                }

                Tab("Library", systemImage: "books.vertical.fill", value: AppTab.profile) {
                    ProfileView(viewModel: profileViewModel)
                        .toolbarVisibility(router.shouldShowTabBar ? .visible : .hidden, for: .tabBar)
                }
            }
            .tint(DSColor.Kraft.darker.color)
            .toolbar(.hidden, for: .navigationBar)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: router.isTabBarHidden)
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
        }
        // Joining a roll by code or invite link (change 024).
        .overlay {
            if let rollViewModel, rollViewModel.isJoining {
                JoiningOverlayView(flowViewModel: rollViewModel)
            }
        }
        .overlay {
            if router.cameraReturnPhase != .idle {
                CameraReturnTransitionOverlay(router: router)
            }
        }
        .overlay {
            if router.isFadingToReveal {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: rollViewModel?.isJoining)
        .animation(.easeInOut(duration: 0.25), value: router.isFadingToReveal)
        .onChange(of: router.path) { _, newPath in
            if !newPath.contains(where: \.isRollRoute) {
                rollViewModel = nil
            }
        }
        .task {
            await archiveSync.run()
        }
        // Shots not in CloudKit yet: pick up uploads that ran while the app was closed, retry the rest (change 020).
        .task {
            await CloudKitSessionService(modelContext: modelContext, enableNetworkMonitoring: false)
                .resumeShotUploads()
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
                scrapbookID: scrapbookID,
                currentUser: currentUser,
                roomService: CloudKitRollRoomService()
            ))
        case .editProfile:
            EditProfileView(viewModel: profileViewModel)
        case .rollReveal(let scrapbookID):
            RollRevealView(viewModel: RollRevealViewModel(
                modelContext: modelContext,
                navigator: router,
                scrapbookID: scrapbookID
            ))
        case .deskCollection(let kind):
            switch kind {
            case .scrapbooks:
                scrapbooksCollectionView
            case .rolls:
                rollsCollectionView
            }
        }
    }

    private var scrapbooksCollectionView: some View {
        let scrapbooks = workbenchViewModel.scrapbooks
        let columns = [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]

        return DeskCollectionView(
            title: "Resume Editing",
            isEmpty: scrapbooks.isEmpty,
            onBack: workbenchViewModel.closeCollection
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(scrapbooks.enumerated()), id: \.element.id) { index, scrapbook in
                    FolderPreviewCard(
                        title: scrapbook.title,
                        subtitle: workbenchViewModel.formattedDate(for: scrapbook),
                        theme: workbenchViewModel.folderTheme(at: index),
                        previewPhotos: workbenchViewModel.previewPhotos(for: scrapbook),
                        onTap: { workbenchViewModel.openScrapbook(scrapbook) },
                        onRemoveFromDevice: { workbenchViewModel.requestRemoveFromDevice(scrapbook) }
                    )
                }
            }
        } emptyState: {
            DeskEmptyStateView(
                title: "No scrapbook in progress...yet!",
                message: "Every scrapbook starts with a roll. Gather your friends and capture moments together.",
                actionTitle: "Create Roll",
                onAction: workbenchViewModel.startCreateRollFromCollection
            ) {
                ToolboxEmptyIllustration()
            }
        }
        .onAppear { workbenchViewModel.reloadScrapbooks() }
        .confirmationDialog(
            "Remove scrapbook from this device?",
            isPresented: Binding(
                get: { workbenchViewModel.scrapbookPendingRemoval != nil },
                set: { if !$0 { workbenchViewModel.scrapbookPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove from Device", role: .destructive, action: workbenchViewModel.confirmRemoveFromDevice)
        } message: {
            Text("This removes the scrapbook and its photos from your device storage. Collaborators keep their shared copy.")
        }
    }

    private var rollsCollectionView: some View {
        let rolls = workbenchViewModel.activeRolls

        return DeskCollectionView(
            title: "Resume Roll",
            isEmpty: rolls.isEmpty,
            horizontalPadding: 0,
            onBack: workbenchViewModel.closeCollection
        ) {
            LazyVStack(spacing: 10) {
                ForEach(rolls, id: \.id) { session in
                    RollStripCard(
                        title: session.name,
                        joinedCount: workbenchViewModel.joinedCount(for: session),
                        slotsUsed: session.slotsUsed,
                        rollSize: session.rollSize,
                        formattedDate: workbenchViewModel.formattedRollDate(for: session),
                        canisterAsset: workbenchViewModel.canisterAsset(for: session.filter),
                        isHost: workbenchViewModel.isHost(of: session),
                        onTap: {
                            Task { await workbenchViewModel.openRoll(session) }
                        },
                        onLeave: { workbenchViewModel.requestLeaveRoll(session) },
                        onDelete: { workbenchViewModel.requestDeleteRoll(session) }
                    )
                }
            }
        } emptyState: {
            DeskEmptyStateView(
                title: "No roll in progress...yet!",
                message: "Your next little moments are waiting to be captured. Start a roll and make memories with your friends.",
                actionTitle: "Create Roll",
                onAction: workbenchViewModel.startCreateRollFromCollection
            ) {
                RollEmptyIllustration()
            }
        }
        .onAppear { workbenchViewModel.reloadRolls() }
        .task { await workbenchViewModel.refreshActiveRolls() }
        .confirmationDialog(
            "Leave this roll?",
            isPresented: Binding(
                get: { workbenchViewModel.rollPendingLeave != nil },
                set: { if !$0 { workbenchViewModel.rollPendingLeave = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Leave Roll", role: .destructive, action: workbenchViewModel.confirmLeaveRoll)
        } message: {
            if let session = workbenchViewModel.rollPendingLeave,
               workbenchViewModel.isHost(of: session),
               session.participantIDs.contains(where: { $0 != currentUser.appleUserID }) {
                Text("Host control will pass to another participant so everyone else can finish this roll.")
            } else {
                Text("This removes the roll from your Resume Roll list.")
            }
        }
        .confirmationDialog(
            "Delete this room?",
            isPresented: Binding(
                get: { workbenchViewModel.rollPendingDelete != nil },
                set: { if !$0 { workbenchViewModel.rollPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Room", role: .destructive, action: workbenchViewModel.confirmDeleteRoll)
        } message: {
            Text("Everyone in the room will be removed.")
        }
        .alert(
            workbenchViewModel.rollNoticeMessage ?? "",
            isPresented: Binding(
                get: { workbenchViewModel.rollNoticeMessage != nil },
                set: { if !$0 { workbenchViewModel.rollNoticeMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
    }
}
