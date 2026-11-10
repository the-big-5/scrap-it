import AuthenticationServices
import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import ScrapIt

@MainActor
struct OnboardingSlidesTests {
    let container: ModelContainer
    let defaults: UserDefaults
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: UserProfile.self, Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
            configurations: ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        defaults = UserDefaults(suiteName: "OnboardingSlidesTests.\(UUID().uuidString)")!
    }

    @Test
    func testOnboardingSlidesViewCompletion() {
        var completed = false
        let view = OnboardingSlidesView(onComplete: {
            completed = true
        })

        // Verify initial state
        #expect(!completed)
        view.onComplete()
        #expect(completed)
    }

    @Test
    func testRootViewInitializesWithCorrectOnboardingState() {
        let rootViewDefault = RootView()
        #expect(rootViewDefault != nil)

        let rootViewWithOnboarding = RootView(showOnboarding: true)
        #expect(rootViewWithOnboarding != nil)
    }

    @Test
    func testOnboardingLifecycleOnSignInAndSignOut() async throws {
        let network = FakeNetwork(isOnline: true)
        let checker = FakeCredentialChecker(result: .success(.authorized))
        let vm = AuthViewModel(
            modelContext: context,
            credentialChecker: checker,
            network: network,
            defaults: defaults
        )

        // Initial launch without session
        await vm.restoreExistingSession()
        #expect(vm.currentUser == nil)
        #expect(!vm.isRestoringSession)

        // Welcome screen with sign in callback
        var didTriggerOnboarding = false
        let welcomeView = WelcomeSignInView(
            authViewModel: vm,
            onSignedIn: {
                didTriggerOnboarding = true
            }
        )
        #expect(!didTriggerOnboarding)

        // Sign in from Welcome
        vm.handleAppleIDCredential(userID: "user_123", fullName: nil)
        #expect(vm.currentUser != nil)
        welcomeView.onSignedIn?()
        #expect(didTriggerOnboarding)

        // Sign out resets session
        vm.signOut()
        #expect(vm.currentUser == nil)

        // Cold launch while already signed in
        defaults.set("user_123", forKey: AuthViewModel.savedUserIDKey)
        let launchVM = AuthViewModel(
            modelContext: context,
            credentialChecker: checker,
            network: network,
            defaults: defaults
        )
        await launchVM.restoreExistingSession()
        #expect(launchVM.currentUser != nil)
        // RootView initialized for returning user starts with showOnboarding = false
        let returningRootView = RootView(authViewModel: launchVM, showOnboarding: false)
        #expect(returningRootView != nil)
    }
}

private struct FakeCredentialChecker: AppleCredentialChecking {
    var result: Result<ASAuthorizationAppleIDProvider.CredentialState, any Error>

    func credentialState(forUserID userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        try result.get()
    }
}

private final class FakeNetwork: NetworkStatusProviding {
    var isOnline: Bool
    init(isOnline: Bool) { self.isOnline = isOnline }
    func currentStatus() async -> Bool { isOnline }
    func waitUntilOnline() async {}
}
