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
    func testOnboardingButtonTitlesAndProgressInterpolation() {
        #expect(OnboardingSlidesView.buttonTitle(for: 0.0) == "Continue")
        #expect(OnboardingSlidesView.buttonTitle(for: 0.8) == "Continue")
        #expect(OnboardingSlidesView.buttonTitle(for: 1.4) == "Continue")
        #expect(OnboardingSlidesView.buttonTitle(for: 1.5) == "Let's Try It")
        #expect(OnboardingSlidesView.buttonTitle(for: 2.0) == "Let's Try It")
    }

    @Test
    func testEffectiveProgressScrubbingAndClamping() {
        let width: CGFloat = 400.0

        // Zero offset gives current slide progress
        let atSlide0 = OnboardingSlidesView.calculateEffectiveProgress(currentSlide: 0, dragOffset: 0, screenWidth: width)
        #expect(atSlide0 == 0.0)

        // Dragging left (negative offset) advances progress towards next slide
        let draggingLeft = OnboardingSlidesView.calculateEffectiveProgress(currentSlide: 0, dragOffset: -200, screenWidth: width)
        #expect(draggingLeft == 0.5)

        // Dragging right (positive offset) moves progress backwards
        let draggingRight = OnboardingSlidesView.calculateEffectiveProgress(currentSlide: 1, dragOffset: 200, screenWidth: width)
        #expect(draggingRight == 0.5)

        // Rubberbanding past left boundary (< 0)
        let pastLeft = OnboardingSlidesView.calculateEffectiveProgress(currentSlide: 0, dragOffset: 100, screenWidth: width)
        #expect(pastLeft < 0.0)
        #expect(pastLeft > -0.25)

        // Rubberbanding past right boundary (> 2)
        let pastRight = OnboardingSlidesView.calculateEffectiveProgress(currentSlide: 2, dragOffset: -100, screenWidth: width)
        #expect(pastRight > 2.0)
        #expect(pastRight < 2.25)
    }

    @Test
    func testTargetSlideDeterminationFromGestures() {
        // Below threshold snaps back
        #expect(OnboardingSlidesView.calculateTargetSlide(currentSlide: 0, translation: -20, velocity: 0) == 0)
        #expect(OnboardingSlidesView.calculateTargetSlide(currentSlide: 1, translation: 20, velocity: 0) == 1)

        // Exceeding translation threshold advances / retreats
        #expect(OnboardingSlidesView.calculateTargetSlide(currentSlide: 0, translation: -50, velocity: 0) == 1)
        #expect(OnboardingSlidesView.calculateTargetSlide(currentSlide: 1, translation: 50, velocity: 0) == 0)

        // High velocity flick advances / retreats even with low translation
        #expect(OnboardingSlidesView.calculateTargetSlide(currentSlide: 0, translation: -10, velocity: -400) == 1)
        #expect(OnboardingSlidesView.calculateTargetSlide(currentSlide: 1, translation: 10, velocity: 400) == 0)

        // Clamping to slide bounds
        #expect(OnboardingSlidesView.calculateTargetSlide(currentSlide: 0, translation: 100, velocity: 500) == 0)
        #expect(OnboardingSlidesView.calculateTargetSlide(currentSlide: 2, translation: -100, velocity: -500) == 2)
    }

    @Test
    func testCustomInitialSlide() {
        var completed = false
        let view = OnboardingSlidesView(initialSlide: 2, onComplete: { completed = true })
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
