# Tech
- Platform: iOS (ScrapIt.xcodeproj) [Locked]
- Minimum iOS: 18 [Locked]
- Devices: iPhone and iPad [Locked]
- Orientation: for now every screen is portrait, except the Capture session where the camera body UI remains landscape (change 008, dual landscape rotation under orientation lock change 037, portrait photo capture and viewfinder HUD rotation change 057, per-screen lock via `OrientationLock` in `Core/Services/` and `AppDelegate` in `App/`). Photos captured in portrait orientation are saved upright in portrait (change 057). Exiting the Capture session immediately requests portrait orientation before navigation transitions (change 056). Supporting both portrait and landscape on the other screens later: [Open]
- UI: SwiftUI [Locked]
- Architecture: MVVM with @Observable [Locked]
- Persistence: SwiftData [Locked]
- Sync/backend: CloudKit [Locked]
- Sharing: CKShare (CloudKit sharing) for roll rooms; scrapbook photos in the public database, encrypted, readable only with the roll key from the room (change 012) [Locked]
- Auth: Sign in with Apple / iCloud only [Locked]
- Invites: share sheet with invite link [Locked]
- Camera: AVFoundation custom camera (`CameraEngine`, ported from the camera POC): multi-lens virtual back camera, filtered live preview (Core Image + Metal), one filter pipeline for preview / photo / Live Photo movie (B&W: `photoEffectNoir`; 200 Color Print: Digicam look from the camera POC, change 016), `RotationCoordinator` rotation, iOS 18 Camera Control "Zoom" slider, mechanical shutter pressed animation and analog shutter haptic (`HapticService.playShutterClick`, change 040) [Locked]
- Third-party libraries: `supabase-swift` (approved for Realtime slot count sync, change 011); only specific ones approved [Locked]
- Scrapbook drawing: PencilKit (iOS 13+, system framework). The Pencil tray picks the tools (no system tool picker, no reed pen; change 022); drawings are layer items stored in a fixed 600 × 800 space and zoomed to the page; only the layer being drawn is a `PKCanvasView`, the others are cached still images (light ink in dark mode). A page drawing from before 022 moves into one back layer when the page is opened. PaperKit markup (iOS 26) not used (change 013)
- Scrapbook sync (change 042, 062): all toolbar item kinds (`photo`, Travel and Fun `sticker`, `letter`, `text`, `washi`, `drawing` layers), transforms (`item_transformed`, including Live Photo `loopEnabled`), text edits (`item_text_updated`), scissors cuts and undo (`item_cut`, `item_cut_undone`), item deletions (`item_removed`), shared sticker sheet locks + `"Take a New Sheet"` (`sticker_sheet_reset`), backgrounds (`page_background`), and page add/move/delete (`page_added`, `page_moved`, `page_deleted`) broadcast live via Supabase Realtime (`ScrapbookEvent` / `ScrapbookItemPayload`). Pencil drawing layers sync per `itemID` with Last-Write-Wins (refreshing an active `PKCanvasView` via `remoteDrawingRevision` while keeping `itemID == nil` page-level `drawing_updated` as a legacy fallback). Placed `photoID`s across all scrapbook pages enforce shared single-use slots in `PhotoTray`, and local or remote removal/page deletion restores unused `stickerID` slots in `StickerSheet.usedStickerIDs`.
- Live Photo loops (change 023): the audio session is set to `.ambient` before a loop plays, so other apps' music keeps playing
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
- Room errors (change 019): CloudKit detail for join, accept-share and invite-link failures is logged with `Logger(subsystem: "ScrapIt", category: "RollRoom")`; the UI shows only short messages (no DEBUG detail on screen). A participant's Leave Room ignores a CloudKit failure (from 011): offline, the name can stay in the host's lobby [Open]
- Back camera lens switching (change 018): on virtual multi-lens back cameras the lens is locked (`.locked`) between zooms and may only change while the zoom changes (`.restricted(.videoZoomChanged)`, locked again 0.6 s after the zoom settles), so iOS no longer switches to the ultra-wide on its own for close subjects (automatic macro). Single-lens phones (e.g. iPhone Air) and the front camera are unchanged. Very close subjects (under ~15–20 cm) stay blurry instead of switching to macro; a manual macro option: [Open]
- Digicam look (change 016, yellow 200 Color Print canister; the UI name stays "200 Color Print", renaming is up to design [Open]): 33³ color cube (`DigicamGrade`: −0.6 EV, S-curve 0.18, warm shadows, saturation 1.2, output 0.03–0.9) → Gaussian blur 0.6 → luminance sharpen 0.4 → vignette 0.5 / 1.5, no grain. The Digicam still photo is scaled to 2048 px (Lanczos, exact size) **before** the look so it matches the preview; preview and Live Photo frames are not scaled
- Choose Filter samples (change 017): 4 bundled photos per filter (`Assets.xcassets/FilterSamples/`, 720 px) rendered at runtime with `FilmFilterPipeline` (`FilterSampleRenderer`, cached), so they always match the camera
- Sample photo license (change 017) [Open]: the photos are from Freepik. A free Freepik license needs a credit (Freepik / the author) where they are used; Premium does not. Not decided which applies or where a credit goes (options: small "Sample photos: Freepik" text on the Choose Filter page, a Credits / About screen, the App Store description as an extra). Check the license file of the Freepik download. Source file names are listed in `spec/changes/archive/017-filter-sample-photos.md`
- Photo & movie compression (change 014): Still photos are proportionally downsampled to max 2048px on the longest edge (4:3 ratio preserved, zero cropping) with 0.78 JPEG quality. Live Photo movies are proportionally capped to max 1440px on the longest edge (1080p standard) and encoded in HEVC with average bitrate ~2.5 Mbps (~1.4 MB total per shot, ~85% reduction) [Locked]
- Restore (change 012): on every launch after sign-in and when a roll ends, `ScrapbookArchiveSync` reads the user's own (private) and joined (shared) `Roll-*` zones, and for ended rolls downloads, decrypts and rebuilds missing scrapbooks / photos (Live Photos included). Leaving a roll or the host deleting it removes access to its photos: [Open]
- Privacy of encrypted public storage (vs members-only CKShare): product sign-off [Open]
- Before Production (CloudKit Console, manual): remove old `RollShot` fields (sessionID, authorID, authorName, caption, timestamp, imageAsset), keep `RollShot` without indexes, no "World" read in Security Roles
- Duplicates after sync: `UserProfile` keeps the oldest per Apple user ID; roll data is local and restore skips existing ids
- One shared iCloud container / team for all developers: [Open] (each developer currently uses their own)
- Before TestFlight / App Store: deploy the CloudKit schema to Production; after that, model changes can only add fields
- `.xcodeproj` exception (change 008, approved by the user): iPhone supported orientations include Landscape Left / Right; nothing else changed
- Live Photo movies are stored in `ScrapPhoto.livePhotoMovieData`, uploaded inside the encrypted shot and played in the Scrapbook grid (change 012)
- Shared profile thumbnails (change 044): `ProfileAvatarProcessor` downsamples picked avatars to `512` px JPEG (`0.8` quality) for `UserProfile.avatarData`, `200` px (`0.7`) for CloudKit `RollParticipant["avatarData"]` in `Roll-<code>` zones (synced on create/join/re-enter), and `80` px (`0.55`) for `CollaboratorPresence.avatarData` in Supabase Realtime.
- Shot upload (change 020, replaces 015's "upload only at the end"): each shot uploads right after capture, once its slot claim is confirmed (016) and its Live Photo movie is saved; lost-race shots are never uploaded. `RollShot` and `RollShotRef` are saved together as CloudKit long-lived operations (the system finishes them when the app is closed); the encrypted payload waits in `Application Support/PendingShots/` until the save is done. On launch the app picks up those operations and retries every unsynced shot (live and ended rolls), also when the network comes back. Same record names, so no duplicates. Shots of abandoned rolls can stay in CloudKit (accepted). Whether a force-quit stops long-lived operations: [Open] (the launch retry covers it). Local rolls (no iCloud / Simulator) upload nothing
- End Roll sync (change 020): upload what is left, then fetch friends' shots every 3 s until the local count equals the roll's shots used, max 2 minutes; downloads in parallel batches of 6 (`records(for:)`). On device the reveal's count still lags a little behind (a friend's shot appears only after its upload finished and the next 3 s fetch) [Open]
- Reveal tear lock (change 024): the envelope opens when the local photo count reaches the roll's `slotsUsed` or 10 s after the reveal opened; the End Roll sync still runs its 2 minutes after the tear. A friend's shot that hadn't finished uploading (phone off, offline, force-quit) only arrives after that friend is online again, on a later launch here
- Joining overlay (change 024): a CloudKit join can't be cancelled; Cancel hides the overlay, ignores a late failure and calls `leaveRoom` after a late success (not when opened as host)
- Leaving the app right after a photo (change 020): from the shutter on, the shot runs with extra background time (`BackgroundTime.keepAlive`, `beginBackgroundTask`, about 30 s): photo processing, slot claim (016) and its Supabase broadcast, Live Photo movie, upload start. Without it iOS froze the shot until the app was reopened (slot unchanged for others, a participant's last photo missing on the host)
- Saving to Photos (change 021): add-only permission (`NSPhotoLibraryAddUsageDescription` in `ScrapIt-Info.plist`), asked on the first Save; a Live Photo is saved as photo + paired video
- "iPhone Duo" device target: [Open] (not an iOS device, clarify)

## Code structure [Locked]
Feature-first MVVM. Views are dumb; all logic lives in ViewModels.

```text
ScrapIt/
├── App/            ScrapIt.swift, AppDelegate.swift, RootView.swift, MainShellView.swift, FloatingTabBarView.swift (+ TabBarDragMath),
│                   Navigation/ (AppRouter.swift, NavigationRoutes.swift), CloudKitShareHandling (share-accepting scene delegate, IncomingShareInbox)
├── Core/
│   ├── Models/         SwiftData models, one file per type: UserProfile, Scrapbook, ScrapPhoto, CaptureSession, RollFilter, SessionStatus,
│   │                   ScrapbookPage, ScrapbookItem, StickerSheet; PageBackground, StickerCatalog, LetterCatalog, WashiCatalog, TextItemColor;
│   │                   camera logic: ZoomWheelModel, CameraButtonRules, LensSwitchingRule, RollCameraOrientation; AppBrand (app name constant)
│   ├── Services/       CloudKitSessionService, CameraController, CameraEngine, FilmFilterPipeline, PreviewRenderer, LivePhotoMovieWriter,
│   │                   Navigator, SessionStore, OrientationLock, CameraMotionService,
│   │                   AppleCredentialChecker, NetworkMonitor, HapticService, ZoomCapabilities,
│   │                   RollRoomService (CloudKit rooms: RollRoomServicing, CloudKitRollRoomService, RollRoomLocation),
│   │                   RollRealtimeService (RollSlotRealtimeProviding, SupabaseRollSlotRealtimeService, NoopRollSlotRealtimeService), SupabaseConfig,
│   │                   RollShotCrypto (AES-GCM shot payload), ScrapbookArchiveSync (restore),
│   │                   CutGeometry, ScrapbookItemLayout, ScrapbookImageLoader, LiveMovieFileCache, LivePlaybackCoordinator, DeletedScrapbookList,
│   │                   DigicamGrade, FilterSamplePhotos (+ FilterSampleRenderer), ProfileAvatarProcessor
│   └── DesignSystem/   Tokens (Color, Typography, Elevation), Components (Button, Icon, Input), Fonts/, ScrapTheme, OffsetPillButtonStyle, CircleIconButton, LivePhotoPlayerView,
│                       Scrapbook/ (ScrapbookPageView, ScrapbookItemView, PageBackgroundView, LoopingVideoView, ScrapbookDrawingImage, ViewFrameReader, WashiTapeView, TextItemAppearance)
└── Features/
    ├── Auth/           WelcomeSignInView, AuthViewModel
    ├── Home/           WorkbenchView, WorkbenchViewModel, WorkbenchLayout (desk asset frames, uniform scale)
    ├── Profile/        ProfileView, EditProfileView, ProfileViewModel, Components/ (ProfileAvatarView)
    ├── Roll/           CreateRollSetupView, CreateRollFilterView, CreateRollLobbyView, JoinRollView, CaptureSessionView, RollFlowViewModel, Components/ (InviteFriendSheetView, RollInviteShare, RollAvatarView, RollRoomHeader, FilmStripPickerView, FilterCanisterCardView, KnurledZoomWheelView, CaptureEventView, FilteredCameraPreviewView, DebugLastShotView)
    └── Scrapbook/      ScrapbookEditorView, ScrapbookViewModel, Components/ (ScissorsToolView, StickerDragController, StickerSheetOverlay, BackgroundPickerView,
                        TrayStyle, ToolTray, TrayScroll, ScrollPanProbe, SubTrays, TrayDragController, PencilController, PencilTray, DrawingCanvasView,
                        WashiPullOverlay, TextItemEditor, ScrapbookPhotoViewer, ScrapbookTrashCanView)
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
- name, bio, email (optional, read-only from Sign in with Apple), hasCustomName, avatar image (`avatarData`)

### Scrapbook [Locked]
- title, cover photo, created date
- photos (list; the caption field stays in the model but is not shown since change 013)
- members: all members are equal co-owners (no single owner)
- pages and sticker sheets (change 013, this device only); tools whose hint was already shown (change 022)

### ScrapbookPage (change 013) [Draft]
- order, background, items. Max 40 items (change 022). The old page drawing field is only read to move it into a layer

### ScrapbookItem (change 013) [Draft]
- photo id, sticker id, letter id, text + text color, washi id + length + tear seed, or drawing data (change 022; the kind comes from the filled field); center / width (normalized to the page, limits per kind), rotation, z-order, Live motion on / off, scissors cut shape

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
