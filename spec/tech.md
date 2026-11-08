# Tech
- Platform: iOS (ScrapIt.xcodeproj) [Locked]
- Minimum iOS: 18 [Locked]
- Devices: iPhone and iPad [Locked]
- Orientation: for now every screen is portrait, except the Capture session which is landscape only (change 008, per-screen lock via `OrientationLock` in `Core/Services/` and `AppDelegate` in `App/`). Supporting both portrait and landscape on the other screens later: [Open]
- UI: SwiftUI [Locked]
- Architecture: MVVM with @Observable [Locked]
- Persistence: SwiftData [Locked]
- Sync/backend: CloudKit [Locked]
- Sharing: CKShare (CloudKit sharing) for roll rooms; scrapbook photos in the public database, encrypted, readable only with the roll key from the room (change 012) [Locked]
- Auth: Sign in with Apple / iCloud only [Locked]
- Invites: share sheet with invite link [Locked]
- Camera: AVFoundation custom camera (`CameraEngine`, ported from the camera POC): multi-lens virtual back camera, filtered live preview (Core Image + Metal), one filter pipeline for preview / photo / Live Photo movie, `RotationCoordinator` rotation, iOS 18 Camera Control "Zoom" slider [Locked]
- Third-party libraries: `supabase-swift` (approved for Realtime slot count sync, change 011); only specific ones approved [Locked]
- Scrapbook drawing: PencilKit (iOS 13+, system framework). Tool picker built with `PKToolPicker(toolItems:)` (iOS 18) so the reed pen (iOS 26) never shows; the drawing is stored in a fixed 600 × 800 space and zoomed to the page. PaperKit markup (iOS 26) not used (change 013)
- Deleted scrapbooks: their roll IDs are kept in `UserDefaults` (`DeletedScrapbookList`) so `ScrapbookArchiveSync` skips them on this device (change 013)
- Data models: see Data models section below
- Folder conventions / naming: see Code structure section below [Locked]
- Live data during a session: only the shot count (slots used / roll size) and presence (who's in) [Locked]
- Media: still photos and Live Photos, hidden from others until session ends [Locked]
- Live transport: Hybrid (change 011). CloudKit manages durable room state, CKShare, and atomic slot arbitration; Supabase Realtime Broadcast (`roll:<code>` topic, `slot_taken` event) delivers <50ms slot count updates during active camera capture, backed up by 3-second CloudKit polling [Locked]
- CloudKit needs the iCloud entitlement and a paid developer team on a real device; the app must not crash without it
- Sign in with Apple needs the `com.apple.developer.applesignin` entitlement (added in change 004) and a paid developer team. CloudKit is not needed for sign-in
- SwiftData (change 012): two stores. The profile store (`UserProfile`, default store name) syncs to the user's private CloudKit database (change 006; Development environment when run from Xcode). The `Rolls` store (`CaptureSession`, `Scrapbook`, `ScrapPhoto`, and since change 013 `ScrapbookPage`, `ScrapbookItem`, `StickerSheet`) is local only. Models must stay CloudKit-compatible: every attribute optional or with a default, no `@Attribute(.unique)`, relationships optional. Without an iCloud account data stays local; if CloudKit setup fails the app falls back to a local-only store
- Roll rooms (change 011): the host's private database holds a zone `Roll-<code>` with the `RollSession` record and one `RollParticipant` record per person, shared with a zone-wide `CKShare` (read/write for anyone with the link). A public `RollCode-<code>` record maps the code to the share link. Participants use their shared database. Opening a link or code first checks the user's own private database (same iCloud as the host → open as host)
- CloudKit container: `CKContainer.default()` is always `iCloud.<bundle ID>`, so the entitlements must list exactly that container (each developer's own for now)
- iCloud share links need `CKSharingSupported`; CloudKit pushes need Background Modes › Remote notifications. Both are in `ScrapIt-Info.plist` (repo root), merged into the generated Info.plist via `INFOPLIST_FILE` (`.xcodeproj` exception, change 011)
- Rooms use the host's own iCloud storage (private database): a full iCloud gives "Quota Exceeded". Rooms are small; photos no longer go to the user's iCloud (change 012)
- Scrapbook photos (change 012): each shot is a public `RollShot` record named with a random UUID holding one AES-GCM encrypted `payload` asset (photo, Live Photo movie, author, caption, time); no readable fields, no indexes. Each roll has a random 256-bit key (`RollSession.rollKey`, local `CaptureSession.rollKey`). A `RollShotRef` per shot in the room zone is the members-only index.
- Photo & movie compression (change 014): Still photos are proportionally downsampled to max 2048px on the longest edge (4:3 ratio preserved, zero cropping) with 0.78 JPEG quality. Live Photo movies are proportionally capped to max 1440px on the longest edge (1080p standard) and encoded in HEVC with average bitrate ~2.5 Mbps (~1.4 MB total per shot, ~85% reduction) [Locked]
- Restore (change 012): on every launch after sign-in and when a roll ends, `ScrapbookArchiveSync` reads the user's own (private) and joined (shared) `Roll-*` zones, and for ended rolls downloads, decrypts and rebuilds missing scrapbooks / photos (Live Photos included). Leaving a roll or the host deleting it removes access to its photos: [Open]
- Privacy of encrypted public storage (vs members-only CKShare): product sign-off [Open]
- Before Production (CloudKit Console, manual): remove old `RollShot` fields (sessionID, authorID, authorName, caption, timestamp, imageAsset), keep `RollShot` without indexes, no "World" read in Security Roles
- Duplicates after sync: `UserProfile` keeps the oldest per Apple user ID; roll data is local and restore skips existing ids
- One shared iCloud container / team for all developers: [Open] (each developer currently uses their own)
- Before TestFlight / App Store: deploy the CloudKit schema to Production; after that, model changes can only add fields
- `.xcodeproj` exception (change 008, approved by the user): iPhone supported orientations include Landscape Left / Right; nothing else changed
- Live Photo movies are stored in `ScrapPhoto.livePhotoMovieData`, uploaded inside the encrypted shot and played in the Scrapbook grid (change 012)
- "iPhone Duo" device target: [Open] (not an iOS device, clarify)

## Code structure [Locked]
Feature-first MVVM. Views are dumb; all logic lives in ViewModels.

```text
ScrapIt/
├── App/            ScrapIt.swift, AppDelegate.swift, RootView.swift, MainShellView.swift, FloatingTabBarView.swift (+ TabBarDragMath),
│                   Navigation/ (AppRouter.swift, NavigationRoutes.swift), CloudKitShareHandling (share-accepting scene delegate, IncomingShareInbox)
├── Core/
│   ├── Models/         SwiftData models, one file per type: UserProfile, Scrapbook, ScrapPhoto, CaptureSession, RollFilter, SessionStatus,
│   │                   ScrapbookPage, ScrapbookItem, StickerSheet; PageBackground, StickerCatalog;
│   │                   camera logic: ZoomWheelModel, CameraButtonRules; AppBrand (app name constant)
│   ├── Services/       CloudKitSessionService, CameraController, CameraEngine, FilmFilterPipeline, PreviewRenderer, LivePhotoMovieWriter,
│   │                   Navigator, SessionStore, OrientationLock,
│   │                   AppleCredentialChecker, NetworkMonitor, HapticService, ZoomCapabilities,
│   │                   RollRoomService (CloudKit rooms: RollRoomServicing, CloudKitRollRoomService, RollRoomLocation),
│   │                   RollRealtimeService (RollSlotRealtimeProviding, SupabaseRollSlotRealtimeService, NoopRollSlotRealtimeService), SupabaseConfig,
│   │                   RollShotCrypto (AES-GCM shot payload), ScrapbookArchiveSync (restore),
│   │                   CutGeometry, ScrapbookItemLayout, ScrapbookImageLoader, LiveMovieFileCache, LivePlaybackCoordinator, DeletedScrapbookList
│   └── DesignSystem/   Tokens (Color, Typography, Elevation), Components (Button, Icon, Input), Fonts/, ScrapTheme, OffsetPillButtonStyle, CircleIconButton, LivePhotoPlayerView,
│                       Scrapbook/ (ScrapbookPageView, ScrapbookItemView, PageBackgroundView, LoopingVideoView, ScrapbookDrawingImage, ViewFrameReader)
└── Features/
    ├── Auth/           WelcomeSignInView, AuthViewModel
    ├── Home/           WorkbenchView, WorkbenchViewModel, WorkbenchLayout (desk asset frames, uniform scale)
    ├── Explore/        ExploreView (3-tab placeholder)
    ├── Profile/        ProfileView, ProfileViewModel
    ├── Roll/           CreateRollSetupView, CreateRollFilterView, CreateRollLobbyView, JoinRollView, CaptureSessionView, RollFlowViewModel, Components/ (InviteFriendSheetView, RollInviteShare, RollAvatarView, RollRoomHeader, FilmStripPickerView, FilterCanisterCardView, KnurledZoomWheelView, CaptureEventView, FilteredCameraPreviewView, DebugLastShotView)
    └── Scrapbook/      ScrapbookEditorView, ScrapbookViewModel, Components/ (ScissorsToolView, StickerPanel, StickerDragController, PencilCanvasView,
                        BackgroundPickerView, ScrapbookPhotoPickerView)
```

Rules:
- Group by feature, not by layer. No global Views/ or ViewModels/ folder.
- One @Observable ViewModel per feature, placed with that feature's Views. Sub-screens of a feature share the feature's ViewModel.
- Views are dumb: they render ViewModel state and forward user actions to ViewModel methods. No business logic, networking, persistence or CloudKit calls in Views. Views do not access `@Environment(\.modelContext)` or pass database handles to ViewModel methods.
- ViewModels must not import SwiftUI (Foundation, Observation, SwiftData only), so they stay testable.
- No cross-feature imports. Shared code moves to Core/ (models, services, design system).
- Services and persistence (`ModelContext`) are injected into ViewModels and Services (`AuthViewModel`, `SessionStore`, `CloudKitSessionService`, `RollFlowViewModel`, `ScrapbookViewModel`) via initializers at the app root composition level (`RootView`, `MainShellView`), not created inside or passed through Views.
- Feature-only sub-views go in that feature's Components/ folder.
- Cross-feature navigation uses the `Navigator` protocol in `Core/Services/Navigator.swift`, route definitions in `App/Navigation/NavigationRoutes.swift`, implemented by `AppRouter` in `App/Navigation/AppRouter.swift` and injected into feature ViewModels.
- Shared session/scrapbook state across features lives in `SessionStore` (`Core/Services/SessionStore.swift`), injected into `ShelfViewModel`, `RollFlowViewModel`, and `ScrapbookViewModel`.

## Never touch
- .xcodeproj settings, signing, or entitlements
- Do not delete files
- Do not modify main spec/ files except via /merge-change

## Data models
Stored with SwiftData. Only Profile syncs to the user's private CloudKit database; rolls, scrapbooks and photos are local, with their cloud copy in the room (CKShare) and the encrypted public shots (change 012).

### Profile [Locked]
- name, avatar image

### Scrapbook [Locked]
- title, cover photo, created date
- photos (list; the caption field stays in the model but is not shown since change 013)
- members: all members are equal co-owners (no single owner)
- pages and sticker sheets (change 013, this device only)

### ScrapbookPage (change 013) [Draft]
- order, background, PencilKit drawing, items. Max 20 items

### ScrapbookItem (change 013) [Draft]
- photo id or sticker id, center / width (normalized to the page), rotation, z-order, Live motion on / off, scissors cut shape

### StickerSheet (change 013) [Draft]
- sticker set id, used sticker ids, created date

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
- roll key (random, encrypts the roll's shots; change 012)

### Shelf [Locked]
- No stored model. A derived view of the user's scrapbooks.
- Display order: newest first (change 013, temporary cover grid)

### Friendship [Open]
- Undecided whether friend connections are stored.
