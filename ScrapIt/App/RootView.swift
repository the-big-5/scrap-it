import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authViewModel: AuthViewModel?
    @State private var showOnboarding: Bool

    init(authViewModel: AuthViewModel? = nil, showOnboarding: Bool = false) {
        _authViewModel = State(initialValue: authViewModel)
        _showOnboarding = State(initialValue: showOnboarding)
    }

    var body: some View {
        Group {
            if let authViewModel {
                if authViewModel.isRestoringSession {
                    ScrapTheme.creamBackground
                        .ignoresSafeArea()
                } else if let currentUser = authViewModel.currentUser {
                    if showOnboarding {
                        OnboardingSlidesView(
                            onComplete: {
                                showOnboarding = false
                            }
                        )
                    } else {
                        MainShellView(
                            currentUser: currentUser,
                            modelContext: modelContext,
                            onSignOut: {
                                showOnboarding = false
                                authViewModel.signOut()
                            }
                        )
                    }
                } else {
                    WelcomeSignInView(
                        authViewModel: authViewModel,
                        onSignedIn: {
                            showOnboarding = true
                        }
                    )
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
