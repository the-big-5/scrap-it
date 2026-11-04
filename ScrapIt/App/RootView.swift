import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if let currentUser = authViewModel.currentUser {
                MainTabView(currentUser: currentUser)
            } else {
                WelcomeSignInView(authViewModel: authViewModel)
            }
        }
        .onAppear {
            authViewModel.restoreExistingSession(modelContext: modelContext)
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
