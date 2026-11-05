import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isRestoringSession {
                ScrapTheme.creamBackground
                    .ignoresSafeArea()
            } else if let currentUser = authViewModel.currentUser {
                MainTabView(currentUser: currentUser, onSignOut: authViewModel.signOut)
            } else {
                WelcomeSignInView(authViewModel: authViewModel)
            }
        }
        .task {
            await authViewModel.restoreExistingSession(modelContext: modelContext)
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
