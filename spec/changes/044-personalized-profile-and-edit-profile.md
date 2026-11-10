# 044: Personalized Profile Header and Edit Profile Screen
Status: Approved

## Why
The current Profile screen uses a temporary `88` pt icon placeholder, displays only the user's Apple-provided name, and places a `Sign Out` button inline above the scrapbook grid. Users should be able to personalize their avatar photo, display name, and bio, view their Sign in with Apple email as read-only private information, and sign out from a dedicated Edit Profile screen (Figma `1300:36485` header and `1300:36781` Edit Profile), while keeping the wooden shelf UI and top-right share button deferred. In addition, updated profile photos should propagate alongside display names to Roll Lobby / Join Room avatars and Scrapbook collaborator presence headers.

## Touches
flows.md (F1: Sign in, F4: Profile shelf), ui.md (Profile tab, Edit Profile, Create Roll Lobby, Scrapbook editor), tech.md (Data models: Profile, Code structure)

## Changes
- MODIFIED `ScrapIt/Core/Models/UserProfile.swift`:
  - Add CloudKit-compatible fields with defaults / optionality:
    - `var bio: String = ""`
    - `var email: String? = nil`
    - `var hasCustomName: Bool = false`
  - Retain `appleUserID`, `name`, `avatarData` (`@Attribute(.externalStorage)`), and `createdAt`.
- MODIFIED `ScrapIt/Features/Auth/WelcomeSignInView.swift`:
  - Update `SignInWithAppleButton` `requestedScopes` from `[.fullName]` to `[.fullName, .email]`.
- MODIFIED `ScrapIt/Features/Auth/AuthViewModel.swift`:
  - Update `handleSignInWithAppleCompletion` and `handleAppleIDCredential` (`email: String? = nil`) to capture `credential.email`.
  - In `completeSignIn`: save `email` onto `UserProfile` when Apple provides a non-empty value; only update `existing.name` from `appleName` when `!existing.hasCustomName`.
- MODIFIED `ScrapIt/App/Navigation/NavigationRoutes.swift`:
  - Add `case editProfile` to `AppRoute` (`isRollRoute == false`).
- MODIFIED `ScrapIt/App/MainShellView.swift`:
  - Share a single `ProfileViewModel` instance (or factory scoped per active profile flow) between `ProfileView` on `.profile` and `EditProfileView` for `AppRoute.editProfile`, passing `onSignOut`.
- ADDED `ScrapIt/Core/Services/ProfileAvatarProcessor.swift`:
  - Downsamples picked image bytes to max `512` px JPEG (`~0.8` quality) via `ImageIO` / `CoreGraphics` so `ProfileViewModel` stays free of `SwiftUI`/`UIKit` imports and `avatarData` stays lightweight for private CloudKit sync.
  - Parameterize `compressionQuality` (and support smaller thumbnail sizes: `200` px @ `0.7` for CloudKit `RollParticipant` records and `80` px @ `0.55` for Supabase `CollaboratorPresence`).
- MODIFIED `ScrapIt/Features/Profile/ProfileViewModel.swift`:
  - Expose read-only `displayName`, `bioText` (or `nil`/empty check for `"No bio yet"` placeholder), `avatarData`, and `emailText` (read-only, fallback `"Not provided"` when `nil` or empty).
  - Add Edit Profile draft state (`draftName`, `draftBio`, `draftAvatarData`, `isShowingSignOutConfirmation`) and actions (`openEditProfile()`, `prepareEditDraft()`, `setDraftAvatar(rawData:)`, `removeDraftAvatar()`, `saveProfileChanges()`, `cancelEditProfile()`, `requestSignOut()`, `confirmSignOut()`).
  - `saveProfileChanges()` trims whitespace, keeps the existing name if the trimmed name is empty, sets `hasCustomName = true` when the name changes, persists `name`, `bio`, and `avatarData` to `ModelContext`, and pops back to Profile.
- MODIFIED `ScrapIt/Features/Profile/ProfileView.swift` (Figma `1300:36485` header only):
  - Use `DSColor.Kraft.lightActive.color` (`#F7F2EB`) background.
  - Render the `120×120` circular avatar (`avatarData` image clipped to circle, or `#C4C4C4` circular placeholder when `nil`).
  - Render centered `20` pt Bold display name with a trailing `pencil` icon button that calls `viewModel.openEditProfile()`.
  - Render centered `13` pt italic bio (`"No bio yet"` when `bio` is empty).
  - Remove the inline `Sign Out` button from `ProfileView`; keep the existing 2-column `scrapbookGrid` and delete confirmation dialog below the header unchanged.
- ADDED `ScrapIt/Features/Profile/EditProfileView.swift` (Figma `1300:36781`):
  - `DSColor.Kraft.lightActive.color` background and `.navigationBarBackButtonHidden(true)` custom top bar:
    - Leading `BackCircleButton` (`chevron.left`) calling `viewModel.cancelEditProfile()`, centered `"Edit Profile"` title, trailing `CircleIconButton(systemName: "checkmark", ...)` calling `viewModel.saveProfileChanges()`.
  - `120×120` circular avatar preview with bottom-right `camera` badge opening `PhotosPicker` (and `"Remove Photo"` action when an avatar image is present).
  - Grouped card 1 (`DSColor.Paper.lightActive.color`, `1` pt `DSColor.Brand.primary.color` border, `26` pt corner radius): `"Name"` and `"Bio"` editable rows.
  - `"Private Information"` section header + Grouped card 2: `"Email"` row displaying read-only `viewModel.emailText` in secondary style (non-editable).
  - Bottom `"Log out"` pill button (`OffsetPillButtonStyle` with `DSColor.Paper.light.color`, `DSColor.Brand.tertiary.color` text, `7` pt shadow offset) presenting confirmation dialog `"You'll need to sign in again to access your account."` with destructive `"Log Out"` and `"Cancel"`.
- MODIFIED `ScrapIt/Core/Services/RollRoomService.swift`:
  - Add `var avatarData: Data? = nil` to `RoomParticipant`.
  - Add `func updateParticipant(_ user: RoomParticipant, inRoom code: String, zoneOwnerName: String?) async throws` to `RollRoomServicing` (with a default no-op extension so existing mock services remain compatible).
  - In `CloudKitRollRoomService`: store and read `record["avatarData"]` on `RollParticipant` records; implement `updateParticipant` using `.allKeys`; when re-entering an existing room via `joinRoom` or `acceptShare` (either host via `ownRoom` or returning participant), update the `RollParticipant` record if `name` or `avatarData` differs from the fetched snapshot.
- MODIFIED `ScrapIt/Features/Roll/RollFlowViewModel.swift`, `ScrapIt/Features/Roll/CreateRollLobbyView.swift`, and `ScrapIt/Features/Roll/Components/RollAvatarView.swift`:
  - Include `ProfileAvatarProcessor.process(..., maxPixelSize: 200, compressionQuality: 0.7)` in `RoomParticipant` when creating or joining a roll (`createLobbySession`, `createInviteLinkIfNeeded`, `participant(_:)`).
  - Update `lobbyDidAppear(currentUser: UserProfile? = nil)` to refresh the local current-user `lobbyParticipants` entry immediately and call `roomService.updateParticipant` if `currentUser.name` or `avatarData` differs from the room snapshot.
  - In `CreateRollLobbyView`, pass `currentUser` into `lobbyDidAppear(currentUser:)` and pass `currentUser.avatarData` directly for the current user (and `participant.avatarData` for others) into `RollAvatarView`.
  - Update `RollAvatarView` to accept `avatarData: Data? = nil` and render the circular `100` pt photo with `1` pt `ink` border when available, falling back to the initials circle when `nil`.
- MODIFIED `ScrapIt/Core/Services/ScrapbookRealtimeService.swift`, `ScrapIt/Features/Scrapbook/ScrapbookViewModel.swift`, and `ScrapIt/Features/Scrapbook/Components/CollaboratorPresenceHeaderView.swift`:
  - Add `var avatarData: Data? = nil` to `CollaboratorPresence` (optional `Codable` field for backward compatibility).
  - In `ScrapbookViewModel.connectRealtime()`, attach a `80` px @ `0.55` JPEG thumbnail from `currentUser?.avatarData` onto `CollaboratorPresence`.
  - In `CollaboratorPresenceHeaderView.avatarCircle(for:)`, render the collaborator's circular photo (`26×26` pt with white border) when `collaborator.avatarData` is a valid image, falling back to the colored initial circle when `nil`.
- MODIFIED `ScrapItTests/Auth/AuthViewModelTests.swift`, ADDED `ScrapItTests/Profile/ProfileViewModelTests.swift`, and MODIFIED `ScrapItTests/Roll/RollRoomTests.swift` & `ScrapItTests/RollRealtimeServiceTests.swift`:
  - Test first-sign-in email capture, preserving stored email when Apple later sends `nil`, and preserving customized `name` (`hasCustomName == true`).
  - Test `ProfileViewModel` draft editing, blank-name guard, avatar processing/removal, read-only email fallback, and sign-out confirmation callback.
  - Test `RoomParticipant` avatar propagation on create/join and sync on re-entering the lobby after profile edits.
  - Test `CollaboratorPresence` `avatarData` serialization and `ScrapbookViewModel` attaching an avatar thumbnail to presence.
  - Verify `ModelContainerTests` passes with the updated `UserProfile` schema.
- Specs at merge (`/merge-change`):
  - `flows.md`: update F1 step 2 (`Requested data: full name and email` — email stored read-only if provided) and step 5 (Sign out moved into Edit Profile).
  - `ui.md`: update `Screen: Profile tab` (header matches Figma `1300:36485` with existing 2-column grid; shelf & top-right share button remain `[Open]`), document `Screen: Edit Profile` (Figma `1300:36781`), update `Create Roll Lobby` profile photos note, and note collaborator avatars in `Scrapbook editor`.
  - `tech.md`: update `Profile` model fields (`name`, `bio`, `email`, `avatarData`, `hasCustomName`), `Code structure` (`EditProfileView`, `ProfileAvatarProcessor`, `ProfileAvatarView`), and note shared `RollParticipant` / `CollaboratorPresence` avatar thumbnails.

## Tasks
- [x] Add `bio`, `email`, and `hasCustomName` to `UserProfile` in `ScrapIt/Core/Models/UserProfile.swift` (CloudKit-compatible)
- [x] Update `WelcomeSignInView` to request `[.fullName, .email]` and update `AuthViewModel` to store `email` and respect `hasCustomName`
- [x] Add `AppRoute.editProfile` in `ScrapIt/App/Navigation/NavigationRoutes.swift` and wire shared `ProfileViewModel` in `ScrapIt/App/MainShellView.swift`
- [x] Create `ScrapIt/Core/Services/ProfileAvatarProcessor.swift` to downsample/compress picked avatar image data
- [x] Update `ScrapIt/Features/Profile/ProfileViewModel.swift` with profile display properties, edit draft state, avatar update/remove, save validation, and sign-out confirmation
- [x] Update `ScrapIt/Features/Profile/ProfileView.swift` header to match Figma `1300:36485` (120pt avatar, name + pencil button, italic bio/`"No bio yet"`, keeping the existing 2-column scrapbook grid)
- [x] Create `ScrapIt/Features/Profile/EditProfileView.swift` matching Figma `1300:36781` (avatar + camera badge `PhotosPicker`, editable Name/Bio card, read-only Private Information Email card, and Log out button with confirmation dialog)
- [x] Add/update unit tests in `AuthViewModelTests.swift` and `ProfileViewModelTests.swift`, and run tests on iOS Simulator to verify zero regressions
- [x] Add `avatarData` to `RoomParticipant`, implement CloudKit `RollParticipant` `avatarData` read/write and `updateParticipant` sync on create/join/re-enter in `RollRoomService.swift`
- [x] Pass avatar thumbnails in `RollFlowViewModel.swift`, sync updated profile on `lobbyDidAppear(currentUser:)`, and render profile photos in `RollAvatarView.swift` & `CreateRollLobbyView.swift`
- [x] Add `avatarData` thumbnail to `CollaboratorPresence` in `ScrapbookRealtimeService.swift`, attach it in `ScrapbookViewModel.swift`, and render it in `CollaboratorPresenceHeaderView.swift`
- [x] Add unit tests for shared lobby & scrapbook presence avatars (`RollRoomTests.swift`, `RollRealtimeServiceTests.swift`) and verify tests pass on iOS Simulator

## Out of scope
- Implementing the wooden shelf empty/filled scrapbook UI (`1300:36486` / `1109:4648`)
- Implementing the top-right share profile button on `ProfileView` (`1300:36503`)
- Changing `FloatingTabBarView` (keep the current 2-tab design; ignore the old 3-tab bar shown in `1300:36485`)
- Sharing user bios with other users in `RollAvatarView` / `RoomParticipant` or `CollaboratorPresence`
- Allowing users to edit or override the Apple-provided `Email` field

## Implementation findings
- Extracted reusable `ScrapIt/Features/Profile/Components/ProfileAvatarView.swift` so `ProfileView` and `EditProfileView` share the `120` pt circular avatar view without duplication.
- Verified on `iPhone 18 Pro` Simulator (iOS 27.2): `RollRoomTests`, `RollRealtimeServiceTests`, `ScrapbookPresenceAvatarTests`, `ProfileViewModelTests`, and `ScrapItTests` (62 tests in 5 suites) passed; running with `-skip-testing:ScrapItTests/OptimisticShutterSlotClaimTests` passed 229 tests in 22 suites (with 1 pre-existing known issue in `DSContrastTests`). `OptimisticShutterSlotClaimTests` was skipped in that sweep because of its pre-existing SwiftData teardown crash (`BackingData.swift:941`).
