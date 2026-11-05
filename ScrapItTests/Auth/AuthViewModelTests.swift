import AuthenticationServices
import Foundation
import SwiftData
import Testing
@testable import ScrapIt

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
}

private struct CheckFailed: Error {}

@MainActor
struct AuthViewModelTests {
    let container: ModelContainer
    let defaults: UserDefaults
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: UserProfile.self, Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        defaults = UserDefaults(suiteName: "AuthViewModelTests.\(UUID().uuidString)")!
    }

    private func makeViewModel(
        state: Result<ASAuthorizationAppleIDProvider.CredentialState, any Error> = .success(.authorized),
        online: Bool = true
    ) -> AuthViewModel {
        AuthViewModel(
            credentialChecker: FakeCredentialChecker(result: state),
            network: FakeNetwork(isOnline: online),
            defaults: defaults
        )
    }

    private func seedSignedInUser(_ id: String = "apple-123", name: String = "Ana") {
        context.insert(UserProfile(appleUserID: id, name: name))
        try? context.save()
        defaults.set(id, forKey: AuthViewModel.savedUserIDKey)
    }

    private func profileCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? -1
    }

    // MARK: Sign in

    @Test func successCreatesProfileAndSavesID() {
        let vm = makeViewModel()
        var name = PersonNameComponents()
        name.givenName = "Ana"
        name.familyName = "Putri"

        vm.handleAppleIDCredential(userID: "apple-123", fullName: name, modelContext: context)

        #expect(vm.currentUser?.appleUserID == "apple-123")
        #expect(vm.currentUser?.name == "Ana Putri")
        #expect(vm.welcomeMessage == nil)
        #expect(defaults.string(forKey: AuthViewModel.savedUserIDKey) == "apple-123")
        #expect(profileCount() == 1)
    }

    @Test func successReusesExistingProfile() {
        seedSignedInUser()
        let vm = makeViewModel()

        vm.handleAppleIDCredential(userID: "apple-123", fullName: nil, modelContext: context)

        #expect(vm.currentUser?.name == "Ana")
        #expect(profileCount() == 1)
    }

    @Test func cancelStaysOnWelcomeWithoutMessage() {
        let vm = makeViewModel()

        vm.handleSignInWithAppleCompletion(result: .failure(ASAuthorizationError(.canceled)), modelContext: context)

        #expect(vm.currentUser == nil)
        #expect(vm.welcomeMessage == nil)
        #expect(profileCount() == 0)
        #expect(defaults.string(forKey: AuthViewModel.savedUserIDKey) == nil)
    }

    @Test(arguments: [ASAuthorizationError.Code.failed, .unknown, .invalidResponse, .notHandled])
    func failureStaysOnWelcomeWithError(_ code: ASAuthorizationError.Code) {
        let vm = makeViewModel()

        vm.handleSignInWithAppleCompletion(result: .failure(ASAuthorizationError(code)), modelContext: context)

        #expect(vm.currentUser == nil)
        #expect(vm.welcomeMessage == AuthViewModel.signInErrorMessage)
        #expect(profileCount() == 0)
    }

    @Test func retryClearsError() {
        let vm = makeViewModel()
        vm.handleSignInFailure(ASAuthorizationError(.failed))

        vm.beginSignIn()

        #expect(vm.welcomeMessage == nil)
    }

    @Test func offlineBlocksSignIn() {
        let vm = makeViewModel(online: false)

        vm.handleAppleIDCredential(userID: "apple-123", fullName: nil, modelContext: context)

        #expect(vm.isOffline)
        #expect(vm.currentUser == nil)
        #expect(vm.welcomeMessage == AuthViewModel.offlineMessage)
        #expect(profileCount() == 0)
    }

    @Test func offlineFailureShowsOfflineMessage() {
        let vm = makeViewModel(online: false)

        vm.handleSignInFailure(ASAuthorizationError(.failed))

        #expect(vm.welcomeMessage == AuthViewModel.offlineMessage)
    }

    // MARK: Launch restore

    @Test func restoreAuthorizedEntersHome() async {
        seedSignedInUser()
        let vm = makeViewModel(state: .success(.authorized))
        #expect(vm.isRestoringSession)

        await vm.restoreExistingSession(modelContext: context)

        #expect(!vm.isRestoringSession)
        #expect(vm.currentUser?.appleUserID == "apple-123")
    }

    @Test(arguments: [
        ASAuthorizationAppleIDProvider.CredentialState.revoked,
        .notFound,
        .transferred,
    ])
    func restoreNotAuthorizedStaysOnWelcome(_ state: ASAuthorizationAppleIDProvider.CredentialState) async {
        seedSignedInUser()
        let vm = makeViewModel(state: .success(state))

        await vm.restoreExistingSession(modelContext: context)

        #expect(!vm.isRestoringSession)
        #expect(vm.currentUser == nil)
        #expect(defaults.string(forKey: AuthViewModel.savedUserIDKey) == nil)
        #expect(profileCount() == 1, "Local data is kept")
    }

    @Test func restoreCheckErrorStaysOnWelcome() async {
        seedSignedInUser()
        let vm = makeViewModel(state: .failure(CheckFailed()))

        await vm.restoreExistingSession(modelContext: context)

        #expect(vm.currentUser == nil)
        #expect(!vm.isRestoringSession)
    }

    @Test func restoreOfflineStaysOnWelcome() async {
        seedSignedInUser()
        let vm = makeViewModel(state: .success(.authorized), online: false)

        await vm.restoreExistingSession(modelContext: context)

        #expect(vm.currentUser == nil)
        #expect(vm.welcomeMessage == AuthViewModel.offlineMessage)
    }

    @Test func restoreWithoutSavedIDIgnoresExistingProfiles() async {
        context.insert(UserProfile(appleUserID: "apple-other", name: "You"))
        try? context.save()
        let vm = makeViewModel(state: .success(.authorized))

        await vm.restoreExistingSession(modelContext: context)

        #expect(vm.currentUser == nil)
        #expect(!vm.isRestoringSession)
    }

    @Test func restoreAuthorizedWithoutLocalProfileStaysOnWelcome() async {
        defaults.set("apple-123", forKey: AuthViewModel.savedUserIDKey)
        let vm = makeViewModel(state: .success(.authorized))

        await vm.restoreExistingSession(modelContext: context)

        #expect(vm.currentUser == nil)
    }

    // MARK: Sign out

    @Test func signOutClearsUserButKeepsData() async {
        seedSignedInUser()
        let vm = makeViewModel()
        await vm.restoreExistingSession(modelContext: context)
        #expect(vm.currentUser != nil)

        vm.signOut()

        #expect(vm.currentUser == nil)
        #expect(defaults.string(forKey: AuthViewModel.savedUserIDKey) == nil)
        #expect(profileCount() == 1)
    }
}
