# Tech
- Platform: iOS (ScrapIt.xcodeproj) [Locked]
- Minimum iOS: 18 [Locked]
- Devices: iPhone and iPad, all orientations [Locked]
- UI: SwiftUI [Locked]
- Architecture: MVVM with @Observable [Locked]
- Persistence: SwiftData [Locked]
- Sync/backend: CloudKit [Locked]
- Sharing: CKShare (CloudKit sharing) for sessions and scrapbooks [Locked]
- Auth: Sign in with Apple / iCloud only [Locked]
- Invites: share sheet with invite link [Locked]
- Camera: AVFoundation custom camera [Locked]
- Third-party libraries: only specific ones I approve; ask before adding any [Locked]
- Data models: see Data models section below
- Folder conventions / naming: see Code structure section below [Locked]
- Live data during a session: only remaining-slot count and presence (who's in) [Locked]
- Media: still photos and Live Photos, hidden from others until session ends [Locked]
- Live transport: CloudKit only (CKShare, records, subscriptions); last-shot race uses CKModifyRecordsOperation with .ifServerRecordUnchanged; no third-party backend [Locked]. Revisit only if live collaborative scrapbooking needs more than CloudKit [Open]
- CloudKit needs the iCloud entitlement and a paid developer team on a real device; the app must not crash without it
- Sign in with Apple needs the `com.apple.developer.applesignin` entitlement (added in change 004) and a paid developer team. CloudKit is not needed for sign-in
- SwiftData syncs to the user's private CloudKit database (change 006; Development environment when run from Xcode). Models must stay CloudKit-compatible: every attribute optional or with a default, no `@Attribute(.unique)`, relationships optional. Without an iCloud account data stays local; if CloudKit setup fails the app falls back to a local-only store
- CloudKit background pushes need Background Modes › Remote notifications (`.xcodeproj` setting, not set yet) [Open]
- Duplicates after sync: `UserProfile` keeps the oldest per Apple user ID; duplicates of `Scrapbook`, `ScrapPhoto`, `CaptureSession` by `id` are not handled yet [Open]
- One shared iCloud container / team for all developers: [Open] (each developer currently uses their own)
- Before TestFlight / App Store: deploy the CloudKit schema to Production; after that, model changes can only add fields
- "iPhone Duo" device target: [Open] (not an iOS device, clarify)

## Code structure [Locked]
Feature-first MVVM. Views are dumb; all logic lives in ViewModels.

```text
ScrapIt/
├── App/            ScrapIt.swift, RootView, MainTabView, AppRouter, FloatingTabBarView
├── Core/
│   ├── Models/         SwiftData models, one file per type: UserProfile, Scrapbook, ScrapPhoto, CaptureSession, RollFilter, SessionStatus
│   ├── Services/       CloudKitSessionService, CameraController, Navigator (AppRoute/AppTab: 3 tabs, number-free routes), SessionStore,
│   │                   AppleCredentialChecker, NetworkMonitor
│   └── DesignSystem/   Tokens (Color, Typography, Elevation), Components (Button, Icon, Input), Fonts/, ScrapTheme, OffsetPillButtonStyle
└── Features/
    ├── Auth/           WelcomeSignInView, AuthViewModel
    ├── Home/           WorkbenchView, WorkbenchViewModel, Components/ (CuttingMatView, DisposableCameraView, DeskDecorationsView, DeskSurfaceView)
    ├── Explore/        ExploreView (3-tab placeholder)
    ├── Profile/        ProfileView, ProfileViewModel
    ├── Roll/           CameraRollMenuView, CreateRollSetupView, CreateRollFilterView, CreateRollLobbyView, JoinRollView, CaptureSessionView, RollFlowViewModel, Components/ (InviteFriendSheetView, FilmStripPickerView, FilterCanisterCardView)
    └── Scrapbook/      ScrapbookGridView, ScrapbookViewModel, Components/
```

Rules:
- Group by feature, not by layer. No global Views/ or ViewModels/ folder.
- One @Observable ViewModel per feature, placed with that feature's Views. Sub-screens of a feature share the feature's ViewModel.
- Views are dumb: they render ViewModel state and forward user actions to ViewModel methods. No business logic, networking, persistence or CloudKit calls in Views.
- ViewModels must not import SwiftUI (Foundation, Observation, SwiftData only), so they stay testable.
- No cross-feature imports. Shared code moves to Core/ (models, services, design system).
- Services are injected into ViewModels (initializer or protocol), not created inside Views.
- Feature-only sub-views go in that feature's Components/ folder.
- Cross-feature navigation uses the `Navigator` protocol (`AppRoute`, `AppTab`) in `Core/Services/Navigator.swift`, implemented by `AppRouter` in `App/AppRouter.swift` and injected into feature ViewModels.
- Shared session/scrapbook state across features lives in `SessionStore` (`Core/Services/SessionStore.swift`), injected into `ShelfViewModel`, `RollFlowViewModel`, and `ScrapbookViewModel`.

## Never touch
- .xcodeproj settings, signing, or entitlements
- Do not delete files
- Do not modify main spec/ files except via /merge-change

## Data models
Stored with SwiftData, synced to the user's private CloudKit database. Sharing with friends (rolls, shots) goes through `CloudKitSessionService` (CloudKit records / CKShare), not SwiftData sync.

### Profile [Locked]
- name, avatar image

### Scrapbook [Locked]
- title, cover photo, created date
- photos (list, each with caption)
- members: all members are equal co-owners (no single owner)

### Photo [Locked]
- image, optional Live Photo video, caption
- author, timestamp
- source session (which session it came from)

### CaptureSession (a Roll) [Locked]
- name, 6-character rollCode, share URL, CloudKit record name
- hostUserID, participants (ids and names)
- rollSize (24/36/48/72), slotsUsed
- filter (Cinematic 400 B&W / 200 Color Print)
- status: waiting / live / ended
- start time, end time, created scrapbook id

### Shelf [Locked]
- No stored model. A derived view of the user's scrapbooks.
- Display order: [Open]

### Friendship [Open]
- Undecided whether friend connections are stored.
