import AuthenticationServices
import Foundation
import Observation
import SwiftData

@Observable
final class AuthViewModel {
    static let savedUserIDKey = "scrapit.signedInAppleUserID"
    static let signInErrorMessage = "Couldn't sign in. Please try again."
    static let offlineMessage = "You're offline. Connect to the internet to sign in."

    var currentUser: UserProfile?
    var isSignedIn: Bool { currentUser != nil }
    /// True until the launch credential check finishes.
    private(set) var isRestoringSession = true
    private(set) var authErrorMessage: String?

    @ObservationIgnored private let credentialChecker: any AppleCredentialChecking
    @ObservationIgnored private let network: any NetworkStatusProviding
    @ObservationIgnored private let defaults: UserDefaults

    init(
        credentialChecker: any AppleCredentialChecking = AppleCredentialChecker(),
        network: any NetworkStatusProviding = NetworkMonitor(),
        defaults: UserDefaults = .standard
    ) {
        self.credentialChecker = credentialChecker
        self.network = network
        self.defaults = defaults
    }

    var isOffline: Bool { !network.isOnline }

    /// Message shown on Welcome: offline wins over a sign-in error.
    var welcomeMessage: String? {
        isOffline ? Self.offlineMessage : authErrorMessage
    }

    // MARK: - Launch

    /// Enters Home only when online, a saved Apple user ID exists, Apple reports it `.authorized`,
    /// and that user's profile exists locally. Anything else stays on Welcome.
    func restoreExistingSession(modelContext: ModelContext) async {
        defer { isRestoringSession = false }
        currentUser = nil

        guard let userID = defaults.string(forKey: Self.savedUserIDKey) else { return }
        guard await network.currentStatus() else { return }

        let state: ASAuthorizationAppleIDProvider.CredentialState
        do {
            state = try await credentialChecker.credentialState(forUserID: userID)
        } catch {
            return
        }

        switch state {
        case .authorized:
            currentUser = profile(for: userID, in: modelContext)
            if currentUser == nil {
                defaults.removeObject(forKey: Self.savedUserIDKey)
            }
        default:
            defaults.removeObject(forKey: Self.savedUserIDKey)
        }
    }

    // MARK: - Sign in

    /// Called when the user taps "Sign in with Apple", before Apple's sheet shows.
    func beginSignIn() {
        authErrorMessage = nil
    }

    func handleSignInWithAppleCompletion(
        result: Result<ASAuthorization, any Error>,
        modelContext: ModelContext
    ) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                authErrorMessage = Self.signInErrorMessage
                return
            }
            handleAppleIDCredential(
                userID: credential.user,
                fullName: credential.fullName,
                modelContext: modelContext
            )
        case .failure(let error):
            handleSignInFailure(error)
        }
    }

    func handleAppleIDCredential(
        userID: String,
        fullName: PersonNameComponents?,
        modelContext: ModelContext
    ) {
        guard !isOffline else { return }

        let name = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        completeSignIn(
            appleUserID: userID,
            name: name.isEmpty ? "Friend" : name,
            modelContext: modelContext
        )
    }

    func handleSignInFailure(_ error: any Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            authErrorMessage = nil
            return
        }
        authErrorMessage = Self.signInErrorMessage
    }

    // MARK: - Sign out

    /// Keeps local data; only forgets who is signed in.
    func signOut() {
        currentUser = nil
        authErrorMessage = nil
        defaults.removeObject(forKey: Self.savedUserIDKey)
    }

    // MARK: - Private

    private func completeSignIn(
        appleUserID: String,
        name: String,
        modelContext: ModelContext
    ) {
        if let existing = profile(for: appleUserID, in: modelContext) {
            currentUser = existing
        } else {
            let profile = UserProfile(appleUserID: appleUserID, name: name)
            modelContext.insert(profile)
            try? modelContext.save()
            currentUser = profile
        }
        authErrorMessage = nil
        defaults.set(appleUserID, forKey: Self.savedUserIDKey)
    }

    private func profile(for appleUserID: String, in modelContext: ModelContext) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.appleUserID == appleUserID }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
