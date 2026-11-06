import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authViewModel: AuthViewModel?

    var body: some View {
        Group {
            if let authViewModel {
                if authViewModel.isRestoringSession {
                    ScrapTheme.creamBackground
                        .ignoresSafeArea()
                } else if let currentUser = authViewModel.currentUser {
                    MainTabView(
                        currentUser: currentUser,
                        modelContext: modelContext,
                        onSignOut: authViewModel.signOut
                    )
                } else {
                    WelcomeSignInView(authViewModel: authViewModel)
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
