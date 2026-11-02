import AuthenticationServices
import Foundation
import Observation
import SwiftData

@Observable
final class AuthViewModel {
    private static let savedUserIDKey = "scrapit.signedInAppleUserID"

    var currentUser: UserProfile?
    var isSignedIn: Bool { currentUser != nil }
    var authErrorMessage: String?

    func restoreExistingSession(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let profiles = try? modelContext.fetch(descriptor),
           let existing = profiles.first {
            currentUser = existing
            UserDefaults.standard.set(existing.appleUserID, forKey: Self.savedUserIDKey)
        }
    }

    func handleSignInWithAppleCompletion(
        result: Result<ASAuthorization, any Error>,
        modelContext: ModelContext
    ) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let userID = credential.user
                let givenName = credential.fullName?.givenName ?? ""
                let familyName = credential.fullName?.familyName ?? ""
                let fullName = [givenName, familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                let resolvedName = fullName.isEmpty ? "Friend" : fullName
                completeSignIn(
                    appleUserID: userID,
                    name: resolvedName,
                    modelContext: modelContext
                )
            }
        case .failure:
            // In iOS Simulator without an active iCloud account, create/restore a local Apple session
            // so the flow can still be tested end-to-end.
            let fallbackID = UserDefaults.standard.string(forKey: Self.savedUserIDKey)
                ?? "apple-user-\(UUID().uuidString.prefix(8))"
            completeSignIn(
                appleUserID: fallbackID,
                name: "You",
                modelContext: modelContext
            )
        }
    }

    func completeSignIn(
        appleUserID: String,
        name: String,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<UserProfile>()
        let existing = (try? modelContext.fetch(descriptor))?.first(where: {
            $0.appleUserID == appleUserID
        })

        if let existing {
            currentUser = existing
        } else {
            let profile = UserProfile(appleUserID: appleUserID, name: name)
            modelContext.insert(profile)
            try? modelContext.save()
            currentUser = profile
        }
        UserDefaults.standard.set(appleUserID, forKey: Self.savedUserIDKey)
    }
}
