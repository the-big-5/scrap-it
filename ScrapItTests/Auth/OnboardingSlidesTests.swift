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
        #expect(OnboardingSlidesView.slideThreeButtonTitle == "Let's Try It")

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
        #expect(rootViewDefault.isShowingOnboarding == true)

        let rootViewWithoutOnboarding = RootView(showOnboarding: false)
        #expect(rootViewWithoutOnboarding.isShowingOnboarding == false)

        let rootViewWithOnboarding = RootView(showOnboarding: true)
        #expect(rootViewWithOnboarding.isShowingOnboarding == true)
    }

    @Test
    func testPreSignInOnboardingFlowAndLifecycle() async throws {
        let network = FakeNetwork(isOnline: true)
        let checker = FakeCredentialChecker(result: .success(.authorized))
        let vm = AuthViewModel(
            modelContext: context,
            credentialChecker: checker,
            network: network,
            defaults: defaults
        )

        // 1. Initial launch without existing session: not authenticated, onboarding shown first
        await vm.restoreExistingSession()
        #expect(vm.currentUser == nil)
        #expect(!vm.isRestoringSession)

        let initialRootView = RootView(authViewModel: vm)
        #expect(initialRootView.isShowingOnboarding == true)

        // 2. Onboarding completion callback sets showOnboarding = false
        var completed = false
        let slidesView = OnboardingSlidesView(onComplete: {
            completed = true
        })
        #expect(!completed)
        slidesView.onComplete()
        #expect(completed)

        // 3. After completing onboarding, RootView presents Welcome without onboarding
        let postOnboardingRootView = RootView(authViewModel: vm, showOnboarding: false)
        #expect(postOnboardingRootView.isShowingOnboarding == false)

        // 4. Sign in from Welcome: user transitions directly to authenticated state (Home)
        vm.handleAppleIDCredential(userID: "user_123", fullName: nil)
        #expect(vm.currentUser != nil)
        #expect(vm.isSignedIn)

        // 5. Sign out resets session: onboarding is presented again before Welcome
        vm.signOut()
        #expect(vm.currentUser == nil)
        #expect(!vm.isSignedIn)
        let postSignOutRootView = RootView(authViewModel: vm, showOnboarding: true)
        #expect(postSignOutRootView.isShowingOnboarding == true)

        // 6. Cold launch with restored session: returning user bypasses onboarding to Home
        defaults.set("user_123", forKey: AuthViewModel.savedUserIDKey)
        let launchVM = AuthViewModel(
            modelContext: context,
            credentialChecker: checker,
            network: network,
            defaults: defaults
        )
        await launchVM.restoreExistingSession()
        #expect(launchVM.currentUser != nil)
        let returningRootView = RootView(authViewModel: launchVM)
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
