# 004: Fix authentication app flow
Status: Approved

## Why
Sign in with Apple looks like it works, but Apple never asks the user to verify their Apple Account (Face ID / password). Three causes found in code:
1. `ScrapIt.entitlements` has no Sign in with Apple capability (`com.apple.developer.applesignin`), so every request fails right away.
2. `AuthViewModel.handleSignInWithAppleCompletion` hides the failure: on `.failure` (including Cancel) it creates a fake local user "You" and signs in.
3. `AuthViewModel.restoreExistingSession` on launch signs in with the newest `UserProfile` in SwiftData without asking Apple if the Apple ID is still valid.

CloudKit is not needed for sign-in. Sign in with Apple (AuthenticationServices) works on its own; CloudKit stays only for data sync and sharing.

## Touches
flows.md (F1), ui.md (Welcome / Sign in, Profile tab), tech.md (entitlements note only)

## Changes
- MODIFIED entitlements: add the Sign in with Apple capability (`com.apple.developer.applesignin` = `Default`). One-time exception to tech.md "Never touch entitlements", approved by the user for this change. Other entitlement keys stay as they are.
- MODIFIED F1 sign in:
  - Tapping "Sign in with Apple" shows Apple's sheet; Apple verifies the Apple Account (Face ID / passcode on device, password on Simulator). Only on success is the profile created or loaded.
  - Requested scope: full name only (no email).
  - Failure or Cancel: stay on Welcome. No fake user. Failure shows an error message; Cancel shows nothing.
  - Offline: cannot sign in; stay on Welcome with an offline message.
- MODIFIED F1 already signed in (app launch):
  - Read the saved Apple user ID, ask Apple for its credential state (`getCredentialState(forUserID:)`).
  - `.authorized` → load that user's `UserProfile` and go to Home.
  - `.revoked`, `.notFound`, error, or offline → go to Welcome (cannot enter).
  - No saved Apple user ID → Welcome. Do not pick "any" profile from SwiftData anymore.
- ~~ADDED F1 revoked while running: listen to `credentialRevokedNotification` and sign out.~~ Removed by user at approval. A revoked Apple ID is caught on the next launch instead.
- ADDED Sign out (temporary, until the Profile design is ready): a "Sign Out" button on the Profile tab. It clears the current user and the saved Apple user ID and returns to Welcome. Local data (`UserProfile`, scrapbooks, photos) is kept, not deleted.
- ADDED Welcome messages [Draft], text for review:
  - Error: "Couldn't sign in. Please try again."
  - Offline: "You're offline. Connect to the internet to sign in."
- Structure (follows tech.md MVVM):
  - Credential check and network check sit behind small protocols in `Core/Services/` so `AuthViewModel` can be tested with fakes.
  - Sign out flows RootView → MainTabView → ProfileView as a closure; Profile does not import the Auth feature.
  - Sign-out button uses the 003 design-system `DSButton`.

## Tasks
- [x] Add `com.apple.developer.applesignin` (`Default`) to `ScrapIt/ScrapIt.entitlements`
- [x] Add `AppleCredentialChecking` protocol + live implementation (wraps `ASAuthorizationAppleIDProvider().credentialState(forUserID:)`) in `Core/Services/`
- [x] Add `NetworkStatusProviding` protocol + live implementation (`NWPathMonitor`) in `Core/Services/`
- [x] `AuthViewModel`: remove the fake-user fallback; handle success, cancel (no message), other errors (error message)
- [x] `AuthViewModel`: block sign-in when offline (offline message)
- [x] `AuthViewModel`: launch restore uses saved Apple user ID + credential state + network; only `.authorized` and online enters Home
- [x] `AuthViewModel`: `signOut()` clears current user and saved Apple user ID
- [x] `WelcomeSignInView`: show the error / offline message; keep requested scope `.fullName`
- [x] `RootView` / `MainTabView` / `ProfileView`: pass a sign-out closure; temporary "Sign Out" `DSButton` on Profile
- [x] Unit tests (Swift Testing) for `AuthViewModel` with fake checker + network: success, cancel, error, offline sign-in, restore for each credential state, restore offline, no saved ID, sign out
- [x] Build and run tests on Simulator
- [ ] Manual check on a real iPhone (Apple sheet + Face ID appears on first sign-in) — for the user

## Out of scope
- Auto sign-out while the app is running when the Apple ID is revoked (`credentialRevokedNotification`); removed by user at approval
- CloudKit changes (sync, sharing, iCloud account status)
- Email scope or showing/verifying the email
- Face ID app lock on every launch (LocalAuthentication)
- Final Profile design and where Sign Out lives long-term (Profile tab is [Open])
- Deleting local data on sign out, account deletion
- Other uncommitted signing changes (team, bundle ID, iCloud/push entitlements) already in the working tree
- Restyling Welcome to the 003 design system

## Notes
- Face ID only appears on first sign-in (or after sign out). Later launches go straight to Home after the silent credential check; that is normal Sign in with Apple behavior.
- Simulator has no Face ID: it must be signed in to an Apple Account in Settings and asks for the password. Test Face ID on a real iPhone.
- Sign in with Apple needs a paid developer team (user confirmed the team is set up).
- After this change, the existing test install has a profile from the fake "You" user; first launch will go to Welcome because there is no valid Apple credential. Delete and reinstall the app for a clean test.

## Implementation findings
- While the launch check runs, RootView shows only the cream background (no Welcome flash, no new UI).
- Offline on Welcome: the Sign in with Apple button is disabled (50% opacity) and the offline message shows; it updates live when the network comes back.
- Messages use `DSColor.Component.inputError`, 13pt; the rest of Welcome is unchanged.
- Sign Out button: `DSButton` `.secondary`, below the status text on Profile.
- Test container uses `cloudKitDatabase: .none`; without it SwiftData tries CloudKit and fails to load (see next point).
- [Conflict, not fixed] The uncommitted entitlements add CloudKit (`iCloud.Brian.ScrapIt`). With that, SwiftData turns on CloudKit sync for the app store, and the current models are not CloudKit-compatible (non-optional attributes without defaults, `@Attribute(.unique)`). Log: "CoreData: error: Store failed to load ... CloudKit integration requires that all attributes be optional, or have a default value set". Effect on this change: the `UserProfile` may not persist, so after relaunch the user can land on Welcome even when signed in. Fix needs a decision (models made CloudKit-compatible, or `ModelConfiguration(cloudKitDatabase: .none)` in `ScrapIt.swift`), which is outside this change (CloudKit is Out of scope).
- Tests: 26 tests in 5 suites pass on iOS 27.1 Simulator (`IPHONEOS_DEPLOYMENT_TARGET=26.6` override), 1 known issue (toggle contrast from 003).
