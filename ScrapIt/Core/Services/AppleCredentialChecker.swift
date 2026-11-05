import AuthenticationServices

/// Asks Apple whether a Sign in with Apple user ID is still valid.
protocol AppleCredentialChecking {
    func credentialState(forUserID userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState
}

struct AppleCredentialChecker: AppleCredentialChecking {
    func credentialState(forUserID userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
    }
}
