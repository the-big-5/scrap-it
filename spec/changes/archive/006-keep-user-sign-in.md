# 006:  keep users signed in + SwiftData CloudKit sync (Development)
Status: Done

## Why
Follow-up to 004. Users must sign in again every time they reopen the app. Cause (recorded [Open] in tech.md during 004): the CloudKit entitlement makes SwiftData turn on CloudKit sync, but the models are not CloudKit-compatible, so the store fails to load:
"Store failed to load ... CloudKit integration requires that all attributes be optional, or have a default value set".
Nothing is saved to disk, so on relaunch the `UserProfile` is missing and `AuthViewModel` sends the user to Welcome. Scrapbooks and photos are not saved either.

Fix: make the models CloudKit-compatible so SwiftData syncs to the user's private iCloud database (Development environment while running from Xcode), and let a signed-in user open the app offline.

## Touches
tech.md (Data models, [Open] SwiftData + CloudKit note, Code structure conflict markers), flows.md (F1)

## Changes
- MODIFIED models (CloudKit-compatible), no new fields, no renames:
  - Every non-optional attribute gets a default value (`UserProfile` 3, `Scrapbook` 5, `ScrapPhoto` 8, `CaptureSession` 11)
  - `@Attribute(.unique)` removed from all four models (CloudKit does not support it)
  - `Scrapbook.photos` becomes optional (`[ScrapPhoto]?`); the 4 call sites use `?? []`
- MODIFIED app model container: SwiftData syncs to the private CloudKit database of the existing container (`com.apple.developer.icloud-container-identifiers`, no entitlement changes). Running from Xcode uses the CloudKit Development environment
- ADDED duplicate handling for `UserProfile`: without `.unique`, the same Apple user can get two profiles (e.g. sign in on a reinstall or second device before iCloud data arrives). Lookup by Apple user ID keeps the oldest profile (`createdAt`) and deletes the others
- MODIFIED F1 already signed in (app launch):
  - Saved Apple user ID + local profile + **offline** → enter Home without the Apple check (was: Welcome)
  - Online → unchanged: check credential state; `.authorized` → Home; `.revoked`, `.notFound`, `.transferred` or check error → Welcome
  - No saved Apple user ID, or no local profile → Welcome (unchanged)
- ADDED F1 deferred check: if the app was entered offline, the Apple credential check runs once when the network comes back. Not `.authorized` (or check error) → sign out to Welcome, same as at launch
- ADDED (user request after approval) profile name from Apple: Apple sends the full name only on the first authorization for an Apple ID + app. On sign-in, if Apple returns a non-empty name that differs from the existing profile's name, the profile name is updated. No name from Apple → profile name unchanged (new profile still defaults to "Friend")
- UNCHANGED: signing in for the first time (or after Sign Out) still needs internet; Welcome offline message and disabled button stay
- ADDED (record only, not built) features that need internet: Create Roll, Join Roll (QR, roll code, share link), invite / share link. Works offline: Home (Workbench), Profile, viewing scrapbooks and photos, editing captions, Sign Out. Mid-roll offline queue stays as in F3. How online-only features look and behave while offline: [Open]
- tech.md at merge:
  - Data models: SwiftData syncs to the user's private CloudKit database; sharing with friends stays in `CloudKitSessionService` (CKShare)
  - Replace the [Open] "SwiftData + CloudKit store fails to load" note with the resolution
  - Resolve the leftover git conflict markers in "Code structure" (combine both versions: detailed Models/Services/DesignSystem list + `Fonts/`)

## Tasks
- [x] `UserProfile`, `Scrapbook`, `ScrapPhoto`, `CaptureSession`: add default values, remove `@Attribute(.unique)`; make `Scrapbook.photos` optional and update its 4 call sites
- [x] `ScrapIt.swift`: model container uses CloudKit sync (private database, existing container); app must not crash if iCloud is not signed in (data stays local)
- [x] `AuthViewModel`: profile lookup by Apple user ID keeps the oldest and deletes duplicates
- [x] `AuthViewModel`: launch restore enters Home offline when saved ID + local profile exist; online path unchanged
- [x] `AuthViewModel`: deferred credential check when the network comes back after an offline launch (`NetworkStatusProviding` gets a way to observe the change)
- [x] Tests (Swift Testing):
  - schema loads with CloudKit enabled (in-memory container with default CloudKit config does not throw)
  - offline launch with saved ID + profile → Home; offline launch without profile → Welcome
  - deferred check: back online + `.authorized` stays; `.revoked` / `.notFound` / error → Welcome
  - duplicate `UserProfile` → oldest kept, others deleted
  - update 004 test `restoreOfflineStaysOnWelcome` to the new rule
- [x] `AuthViewModel`: update the existing profile's name when Apple returns a non-empty name; tests for update, no-name keeps name, first sign-in without name uses "Friend"
- [x] Build and run all tests on Simulator
- [x] Manual check on a real iPhone signed in to iCloud (done by the user, all passed): sign in, close app, reopen → Home; airplane mode, reopen → Home; log shows no "Store failed to load"; record appears in CloudKit Console (Development, private database, `CD_` record types)

## Out of scope
- How online-only features (Create / Join Roll, invite) look or behave while offline [Open]
- Deploying the schema to CloudKit Production (needed before TestFlight / App Store)
- Duplicate handling for `Scrapbook`, `ScrapPhoto`, `CaptureSession` (see Open)
- Sharing data with friends via SwiftData (stays in `CloudKitSessionService`)
- Unifying the iCloud container / team / bundle ID across developers
- Entitlements, signing, `.xcodeproj` settings
- Migrating existing local data (the store never loaded, so there is none)

## Open
- Duplicates of `Scrapbook`, `ScrapPhoto`, `CaptureSession` by `id` after sync between a user's devices (e.g. the same roll joined on two devices). Handle when multi-device use matters
- One shared iCloud container for the team: right now each developer syncs to their own container (`iCloud.Brian.ScrapIt` vs `iCloud.lepin.scrapit`)
- Before TestFlight: deploy the schema to Production; after that, model changes can only add fields

## Notes
- The device / Simulator must be signed in to iCloud for sync. Without iCloud, data is still saved locally, so staying signed in works either way
- After a reinstall, iCloud data can take a few seconds to arrive. If the user signs in before it arrives, a duplicate profile can appear; the duplicate handling above cleans it up
- Development schema can be reset any time from CloudKit Console

## Implementation findings
- `ScrapIt.swift` builds the container itself (`ScrapIt.makeModelContainer()`, `ScrapIt.schema`): CloudKit `.automatic` first, local-only fallback if that throws, so a CloudKit setup problem never crashes the app
- `CaptureSession.filterRaw` / `statusRaw` default to `RollFilter.colorPrint200` / `SessionStatus.waiting` (same as the init defaults); `ScrapPhoto.imageData` defaults to empty `Data()`
- Offline launch without a local profile keeps the saved Apple user ID (signing in again needs internet anyway)
- `NetworkStatusProviding` gained `waitUntilOnline()`; the deferred check is cancelled on Sign Out or a new sign-in
- Tests: 38 tests in 6 suites pass (35 before the name update) on iOS 27.1 Simulator (`IPHONEOS_DEPLOYMENT_TARGET=26.6` override), 1 known issue (toggle contrast from 003). No "Store failed to load" in the log anymore
- Simulator log shows "Unable to initialize without an iCloud account (CKAccountStatusNoAccount)": expected, the Simulator is not signed in to iCloud; data still saves locally
- Real iPhone log shows "BUG IN CLIENT OF CLOUDKIT: CloudKit push notifications require the 'remote-notification' background mode in your info plist". Sync still works while the app is open; background pushes need Xcode › Signing & Capabilities › Background Modes › Remote notifications (`.xcodeproj` change, not done here)
- CloudKit Console: `CD_UserProfile` appears in Private Database › `com.apple.coredata.cloudkit.zone`. Browsing records needs a Queryable index on `recordName` (Console only, per container; the app does not need it)
