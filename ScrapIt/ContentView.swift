import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authViewModel = AuthViewModel()
    @State private var flowViewModel = RollFlowViewModel()

    var body: some View {
        Group {
            if let currentUser = authViewModel.currentUser {
                HomeContainerView(
                    currentUser: currentUser,
                    flowViewModel: flowViewModel
                )
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
    ContentView()
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
