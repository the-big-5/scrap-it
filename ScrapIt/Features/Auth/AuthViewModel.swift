import AuthenticationServices
import Foundation
import Observation
import SwiftData

@Observable
final class AuthViewModel {
    static let savedUserIDKey = "scrapit.signedInAppleUserID"
    static let signInErrorMessage = "Couldn't sign in. Please try again."
    static let offlineMessage = "You're offline. Connect to the internet to sign in."
    /// Used when Apple sends no name (every sign-in after the first one for this Apple ID).
    static let defaultName = "Friend"

    var currentUser: UserProfile?
    var isSignedIn: Bool { currentUser != nil }
    /// True until the launch credential check finishes.
    private(set) var isRestoringSession = true
    private(set) var authErrorMessage: String?

    @ObservationIgnored private let credentialChecker: any AppleCredentialChecking
    @ObservationIgnored private let network: any NetworkStatusProviding
    @ObservationIgnored private let defaults: UserDefaults
    /// Apple credential check postponed by an offline launch; runs once the network is back.
    @ObservationIgnored private(set) var pendingCredentialCheck: Task<Void, Never>?

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

    /// Needs a saved Apple user ID and that user's local profile.
    /// Online: enters Home only when Apple reports `.authorized`.
    /// Offline: enters Home right away and checks with Apple once the network is back.
    func restoreExistingSession(modelContext: ModelContext) async {
        defer { isRestoringSession = false }
        cancelPendingCredentialCheck()
        currentUser = nil

        guard let userID = defaults.string(forKey: Self.savedUserIDKey) else { return }

        guard await network.currentStatus() else {
            guard let profile = profile(for: userID, in: modelContext) else { return }
            currentUser = profile
            scheduleCredentialCheckWhenOnline(userID: userID)
            return
        }

        guard await isCredentialAuthorized(userID: userID) else {
            defaults.removeObject(forKey: Self.savedUserIDKey)
            return
        }
        currentUser = profile(for: userID, in: modelContext)
        if currentUser == nil {
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

        // Apple sends the name only on the first authorization for this Apple ID and app.
        let name = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        completeSignIn(
            appleUserID: userID,
            appleName: name.isEmpty ? nil : name,
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
        cancelPendingCredentialCheck()
        currentUser = nil
        authErrorMessage = nil
        defaults.removeObject(forKey: Self.savedUserIDKey)
    }

    // MARK: - Private

    private func isCredentialAuthorized(userID: String) async -> Bool {
        do {
            return try await credentialChecker.credentialState(forUserID: userID) == .authorized
        } catch {
            return false
        }
    }

    private func scheduleCredentialCheckWhenOnline(userID: String) {
        pendingCredentialCheck = Task { [weak self, network] in
            await network.waitUntilOnline()
            guard !Task.isCancelled, let self else { return }
            let authorized = await self.isCredentialAuthorized(userID: userID)
            guard !Task.isCancelled, !authorized, self.currentUser?.appleUserID == userID else { return }
            self.signOut()
        }
    }

    private func cancelPendingCredentialCheck() {
        pendingCredentialCheck?.cancel()
        pendingCredentialCheck = nil
    }

    private func completeSignIn(
        appleUserID: String,
        appleName: String?,
        modelContext: ModelContext
    ) {
        cancelPendingCredentialCheck()
        if let existing = profile(for: appleUserID, in: modelContext) {
            if let appleName, existing.name != appleName {
                existing.name = appleName
                try? modelContext.save()
            }
            currentUser = existing
        } else {
            let profile = UserProfile(appleUserID: appleUserID, name: appleName ?? Self.defaultName)
            modelContext.insert(profile)
            try? modelContext.save()
            currentUser = profile
        }
        authErrorMessage = nil
        defaults.set(appleUserID, forKey: Self.savedUserIDKey)
    }

    /// CloudKit sync has no unique constraint, so one Apple user can end up with several profiles
    /// (e.g. signing in on a reinstall before iCloud data arrives). Keeps the oldest, deletes the rest.
    private func profile(for appleUserID: String, in modelContext: ModelContext) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.appleUserID == appleUserID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let profiles = try? modelContext.fetch(descriptor), let oldest = profiles.first else {
            return nil
        }
        if profiles.count > 1 {
            profiles.dropFirst().forEach(modelContext.delete)
            try? modelContext.save()
        }
        return oldest
    }
}
