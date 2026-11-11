import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authViewModel: AuthViewModel?
    @State private var showOnboarding: Bool

    init(authViewModel: AuthViewModel? = nil, showOnboarding: Bool = true) {
        _authViewModel = State(initialValue: authViewModel)
        _showOnboarding = State(initialValue: showOnboarding)
    }

    var isShowingOnboarding: Bool {
        showOnboarding
    }

    var body: some View {
        Group {
            if let authViewModel {
                if authViewModel.isRestoringSession {
                    ScrapTheme.creamBackground
                        .ignoresSafeArea()
                } else if let currentUser = authViewModel.currentUser {
                    MainShellView(
                        currentUser: currentUser,
                        modelContext: modelContext,
                        onSignOut: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                showOnboarding = true
                            }
                            authViewModel.signOut()
                        }
                    )
                } else {
                    ZStack {
                        if showOnboarding {
                            OnboardingSlidesView(
                                onComplete: {
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        showOnboarding = false
                                    }
                                }
                            )
                            .transition(.opacity)
                        } else {
                            WelcomeSignInView(
                                authViewModel: authViewModel
                            )
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.35), value: showOnboarding)
                }
            } else {
                ScrapTheme.creamBackground
                    .ignoresSafeArea()
            }
        }
        .task {
            if authViewModel == nil {
                let vm = AuthViewModel(modelContext: modelContext)
                authViewModel = vm
                await vm.restoreExistingSession()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(
            for: [
                UserProfile.self,
                Scrapbook.self,
                ScrapPhoto.self,
                CaptureSession.self
            ],
            inMemory: true
        )
}
