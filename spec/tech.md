# Tech
- Platform: iOS (ScrapIt.xcodeproj) [Locked]
- Minimum iOS: 18 [Locked]
- Devices: iPhone and iPad [Locked]
- Orientation: on iPhone every screen outside the spread editor is portrait; on iPad, `OrientationLock` defaults and resets to `.all` (`defaultMask(for:)`, change 105) so general screens rotate cleanly and Workbench switches between `.portrait` (`402 × 874`) and `.iPadLandscape` (`1210 × 834`, Figma `1563:34278`). Capture session explicitly locks orientation to `.portrait` on appear on both iPhone and iPad (Option A, change 105; changes 008, 037, 057, 072) so its fixed camera body canvas (`874 × 402`) never clips; individual symbols rotate via accelerometer motion tracking while captured photos save upright 3:4 portrait / 4:3 landscape (changes 057, 071, 072). Entering Capture from the lobby coordinates silent navigation push and 3D film-loading intro through `CameraIntroTransitionOverlay` (change 110); exiting Capture coordinates orientation (`OrientationLock.resetToPortrait()` → `defaultMask()`) and navigation pop through `CameraReturnTransitionOverlay` in `MainShellView` without rotation jumps or duplicate transitions (changes 056, 086, 100, 105, 110). On iPhone, the scrapbook spread editor turns to landscape left / right only while both pages are shown (change 025). On iPad, `OrientationLock.defaultMask(for: .pad)` (`.all`) remains active across all scrapbook modes (`.book`, `.cover`, `.edit`, `.editCover`, change 107).
- UI: SwiftUI [Locked]
- Architecture: MVVM with @Observable [Locked]
- Persistence: SwiftData [Locked]
- Sync/backend: CloudKit [Locked]
- Sharing: CKShare (CloudKit sharing) for roll rooms; scrapbook photos in the public database, encrypted, readable only with the roll key from the room (change 012) [Locked]
- Auth: Sign in with Apple / iCloud only [Locked]
- Invites: share sheet with invite link [Locked]
- Camera: AVFoundation custom camera (`CameraEngine`, ported from the camera POC): multi-lens virtual back camera, filtered live preview (Core Image + Metal), one filter pipeline for preview / photo / Live Photo movie (B&W: `photoEffectNoir`; 200 Color Print: Digicam look from the camera POC, change 016), `RotationCoordinator` rotation, iOS 18 Camera Control "Zoom" slider, mechanical shutter pressed animation and analog shutter haptic (`HapticService.playShutterClick`, change 040) [Locked]
- Third-party libraries: `supabase-swift` (approved for Realtime slot count sync, change 011); only specific ones approved [Locked]
- Scrapbook drawing: PencilKit (iOS 13+, system framework). The Pencil tray picks the tools (no system tool picker, no reed pen; change 022); drawings are layer items stored in a fixed 600 × 800 space and zoomed to the page; only the layers being drawn are `PKCanvasView`s (one per page on screen, change 025; on the spread one canvas over both pages, its strokes split into each page's layer by the page they start on, change 104), the others are cached still images (light ink in dark mode) that include strokes up to one page past the side edges (change 104). A page drawing from before 022 moves into one back layer when the page is opened. PaperKit markup (iOS 26) not used (change 013)
- Scrapbook sync (change 042, 062): all toolbar item kinds (`photo`, Travel and Fun `sticker`, `letter`, `text`, `washi`, `drawing` layers), transforms (`item_transformed`, including Live Photo `loopEnabled`), text edits (`item_text_updated`), scissors cuts and undo (`item_cut`, `item_cut_undone`), item deletions (`item_removed`), shared sticker sheet locks + `"Take a New Sheet"` (`sticker_sheet_reset`), backgrounds (`page_background`), and page add/move/delete (`page_added`, `page_moved`, `page_deleted`) broadcast live via Supabase Realtime (`ScrapbookEvent` / `ScrapbookItemPayload`). Pencil drawing layers sync per `itemID` with Last-Write-Wins (refreshing an active `PKCanvasView` via `remoteDrawingRevision` while keeping `itemID == nil` page-level `drawing_updated` as a legacy fallback). Placed `photoID`s across all scrapbook pages enforce shared single-use slots in `PhotoTray`, and local or remote removal/page deletion restores unused `stickerID` slots in `StickerSheet.usedStickerIDs`.
- Scrapbook cover and finishing (change 026): cover items use the item events with page index -1 (front) / -2 (spine); new Supabase events `editing_done` (memberID), `scrapbook_locked`, `cover_color`; the CloudKit room zone gets `ScrapbookDone` (one per member, `Done-<userID>`) and `ScrapbookLock` records, read when the editor opens so offline friends count
- Drawing space by page shape (change 026): 800 high, width by the page's ratio (600 for 3:4 pages), so strokes keep their size on the narrow spine
- Live Photo loops (change 023): the audio session is set to `.ambient` before a loop plays, so other apps' music keeps playing
- Scrapbook undo / redo (change 025): one history of the spread's pages (all item fields) and sticker sheet slots per edit view visit; every change on this phone records a step, redo steps clear on a new change; undo / redo is sent with the existing events (`item_placed` / `item_removed` / `item_transformed` / `item_text_updated` / `drawing_updated` / `item_cut`), last write wins. Replaces the cut-only and Pencil-only undo
- Scrapbook page hint (change 025): "More pages to fill!" is shown once per user (`UserDefaults` key `scrapbookPageHintShown`)
- Deleted scrapbooks: their roll IDs are kept in `UserDefaults` (`DeletedScrapbookList`) so `ScrapbookArchiveSync` skips them on this device (change 013)
- Data models: see Data models section below
- Folder conventions / naming: see Code structure section below [Locked]
- Live data during a session: only the shot count (slots used / roll size) and presence (who's in) [Locked]
- Media: still photos and Live Photos, hidden from others until session ends [Locked]
- Live transport: Hybrid (change 011). CloudKit manages durable room state, CKShare, and atomic slot arbitration; Supabase Realtime Broadcast (`roll:<code>` topic, `slot_taken` event) delivers <50ms slot count updates during active camera capture, backed up by 3-second CloudKit polling [Locked]. When capturing, `RollFlowViewModel.isSyncingShot` activates immediately on shutter tap, displaying an amber status ring around the shots-left dial with a gentle sync pulse and holding the dial count until CloudKit confirms the claim, firing a single sharp mechanical click upon decrement (change 058)
- CloudKit needs the iCloud entitlement and a paid developer team on a real device; the app must not crash without it
- Sign in with Apple needs the `com.apple.developer.applesignin` entitlement (added in change 004) and a paid developer team. CloudKit is not needed for sign-in
- SwiftData (change 012): two stores. The profile store (`UserProfile`, default store name) syncs to the user's private CloudKit database (change 006; Development environment when run from Xcode). The `Rolls` store (`CaptureSession`, `Scrapbook`, `ScrapPhoto`, and since change 013 `ScrapbookPage`, `ScrapbookItem`, `StickerSheet`) is local only. Models must stay CloudKit-compatible: every attribute optional or with a default, no `@Attribute(.unique)`, relationships optional. Without an iCloud account data stays local; if CloudKit setup fails the app falls back to a local-only store
- Roll rooms (changes 011, 106): the host's private database holds a zone `Roll-<code>` with the `RollSession` record and one `RollParticipant` record per person, shared with a zone-wide `CKShare` (read/write for anyone with the link). A public `RollCode-<code>` record maps the code to the share link. Participants use their shared database. Opening a link or code first checks the user's own private database (same iCloud as the host → open as host). Leaving as host while other participants remain calls `RollRoomServicing.leaveAsHostHandover` to update `RollSession["hostUserID"]` to the next participant and delete only the leaving host's `RollParticipant` record (preserving a creator-owned `CKRecordZone` and `CKShare` so friends can finish the roll)
- CloudKit container: `CKContainer.default()` is always `iCloud.<bundle ID>`, so the entitlements must list exactly that container (each developer's own for now)
- iCloud share links need `CKSharingSupported`; CloudKit pushes need Background Modes › Remote notifications. Both are in `ScrapIt-Info.plist` (repo root), merged into the generated Info.plist via `INFOPLIST_FILE` (`.xcodeproj` exception, change 011)
- Rooms use the host's own iCloud storage (private database): a full iCloud gives "Quota Exceeded". Rooms are small; photos no longer go to the user's iCloud (change 012)
- Scrapbook photos (change 012): each shot is a public `RollShot` record named with a random UUID holding one AES-GCM encrypted `payload` asset (photo, Live Photo movie, author, caption, time); no readable fields, no indexes. Each roll has a random 256-bit key (`RollSession.rollKey`, local `CaptureSession.rollKey`). A `RollShotRef` per shot in the room zone is the members-only index.
- Room errors (change 019): CloudKit detail for join, accept-share and invite-link failures is logged with `Logger(subsystem: "ScrapIt", category: "RollRoom")`; the UI shows only short messages (no DEBUG detail on screen). A participant's Leave Room ignores a CloudKit failure (from 011): offline, the name can stay in the host's lobby [Open]
- Back camera lens switching (change 018, 060): back camera discovery excludes `.builtInTripleCamera` and prioritizes `.builtInDualWideCamera`, `.builtInDualCamera`, and `.builtInWideAngleCamera` so telephoto optical jumps are eliminated (0.5×–0.9× uses Ultra Wide; 1.0×–4.0× uses Main sensor digital crop). Constituent device switching uses `.auto` with `[]` to disable automatic macro switching while keeping AVFoundation's smooth optical transition compositor across the 0.9×/1.0× boundary. Single-lens phones and the front camera are unchanged.
- Digicam look (change 016, yellow 200 Color Print canister; the UI name stays "200 Color Print", renaming is up to design [Open]): 33³ color cube (`DigicamGrade`: −0.6 EV, S-curve 0.18, warm shadows, saturation 1.2, output 0.03–0.9) → Gaussian blur 0.6 → luminance sharpen 0.4 → vignette 0.5 / 1.5, no grain. The Digicam still photo is scaled to 2048 px (Lanczos, exact size) **before** the look so it matches the preview; preview and Live Photo frames are not scaled
- Choose Filter samples (change 017): 4 bundled photos per filter (`Assets.xcassets/FilterSamples/`, 720 px) rendered at runtime with `FilmFilterPipeline` (`FilterSampleRenderer`, cached), so they always match the camera
- Sample photo license (change 017) [Open]: the photos are from Freepik. A free Freepik license needs a credit (Freepik / the author) where they are used; Premium does not. Not decided which applies or where a credit goes (options: small "Sample photos: Freepik" text on the Choose Filter page, a Credits / About screen, the App Store description as an extra). Check the license file of the Freepik download. Source file names are listed in `spec/changes/archive/017-filter-sample-photos.md`
- Photo & movie compression (change 014, 071): Still photos and Live Photo movies are center-cropped to 4:3 (landscape) or 3:4 (portrait) if the input image or video stream differs, matching the fixed viewfinder framing (change 071). Still photos are proportionally downsampled to max 2048px on the longest edge with 0.78 JPEG quality. Live Photo movies are proportionally capped to max 1440px on the longest edge (1080p standard) and encoded in HEVC with average bitrate ~2.5 Mbps (~1.4 MB total per shot, ~85% reduction) [Locked]
- Restore (change 012): on every launch after sign-in and when a roll ends, `ScrapbookArchiveSync` reads the user's own (private) and joined (shared) `Roll-*` zones, and for ended rolls downloads, decrypts and rebuilds missing scrapbooks / photos (Live Photos included). Leaving a roll or the host deleting it removes access to its photos: [Open]
- Privacy of encrypted public storage (vs members-only CKShare): product sign-off [Open]
- Before Production (CloudKit Console, manual): remove old `RollShot` fields (sessionID, authorID, authorName, caption, timestamp, imageAsset), keep `RollShot` without indexes, no "World" read in Security Roles
- Duplicates after sync: `UserProfile` keeps the oldest per Apple user ID; roll data is local and restore skips existing ids
- One shared iCloud container / team for all developers: [Open] (each developer currently uses their own)
- Before TestFlight / App Store: deploy the CloudKit schema to Production; after that, model changes can only add fields
- `.xcodeproj` exceptions (approved by the user): change 008 (iPhone supported orientations include Landscape Left / Right), change 011 (`INFOPLIST_FILE` = `ScrapIt-Info.plist`), and change 134 (`ASSETCATALOG_COMPILER_APPICON_NAME` = `AppIcon`, `INFOPLIST_KEY_CFBundleDisplayName` = `Rèlic`, and `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` moved from `ScrapIt-Info.plist`)
- Live Photo movies are stored in `ScrapPhoto.livePhotoMovieData`, uploaded inside the encrypted shot and played in the Scrapbook grid (change 012)
- Shared profile thumbnails (change 044): `ProfileAvatarProcessor` downsamples picked avatars to `512` px JPEG (`0.8` quality) for `UserProfile.avatarData`, `200` px (`0.7`) for CloudKit `RollParticipant["avatarData"]` in `Roll-<code>` zones (synced on create/join/re-enter), and `80` px (`0.55`) for `CollaboratorPresence.avatarData` in Supabase Realtime.
- Shot upload (change 020, replaces 015's "upload only at the end"): each shot uploads right after capture, once its slot claim is confirmed (016) and its Live Photo movie is saved; lost-race shots are never uploaded. `RollShot` and `RollShotRef` are saved together as CloudKit long-lived operations (the system finishes them when the app is closed); the encrypted payload waits in `Application Support/PendingShots/` until the save is done. On launch the app picks up those operations and retries every unsynced shot (live and ended rolls), also when the network comes back. Same record names, so no duplicates. Shots of abandoned rolls can stay in CloudKit (accepted). Whether a force-quit stops long-lived operations: [Open] (the launch retry covers it). Local rolls (no iCloud / Simulator) upload nothing
- End Roll sync (change 020): upload what is left, then fetch friends' shots every 3 s until the local count equals the roll's shots used, max 2 minutes; downloads in parallel batches of 6 (`records(for:)`). On device the reveal's count still lags a little behind (a friend's shot appears only after its upload finished and the next 3 s fetch) [Open]
- Reveal tear lock (change 024): the envelope opens when the local photo count reaches the roll's `slotsUsed` or 10 s after the reveal opened; the End Roll sync still runs its 2 minutes after the tear. A friend's shot that hadn't finished uploading (phone off, offline, force-quit) only arrives after that friend is online again, on a later launch here
- Joining overlay (change 024): a CloudKit join can't be cancelled; Cancel hides the overlay, ignores a late failure and calls `leaveRoom` after a late success (not when opened as host)
- Leaving the app right after a photo (change 020): from the shutter on, the shot runs with extra background time (`BackgroundTime.keepAlive`, `beginBackgroundTask`, about 30 s): photo processing, slot claim (016) and its Supabase broadcast, Live Photo movie, upload start. Without it iOS froze the shot until the app was reopened (slot unchanged for others, a participant's last photo missing on the host)
- Saving to Photos (change 021): add-only permission (`INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` in `ScrapIt.xcodeproj/project.xcproj`, moved from `ScrapIt-Info.plist`), asked on the first Save; a Live Photo is saved as photo + paired video
- "iPhone Duo" device target: [Open] (not an iOS device, clarify)

## Code structure [Locked]
Feature-first MVVM. Views are dumb; all logic lives in ViewModels.

```text
ScrapIt/
├── App/            ScrapIt.swift, AppDelegate.swift, RootView.swift, MainShellView.swift (native TabView, change 088),
│                   Navigation/ (AppRouter.swift, NavigationRoutes.swift), CloudKitShareHandling (share-accepting scene delegate, IncomingShareInbox)
├── Core/
│   ├── Models/         SwiftData models, one file per type: UserProfile, Scrapbook, ScrapPhoto, CaptureSession, RollFilter, SessionStatus,
│   │                   ScrapbookPage, ScrapbookItem, StickerSheet; PageBackground, StickerCatalog, LetterCatalog, WashiCatalog, TextItemColor;
│   │                   camera logic: ZoomStop, CameraButtonRules, RollCameraOrientation; AppBrand (app name constant `"Rèlic"`, change 134)
│   ├── Services/       CloudKitSessionService, CameraController, CameraEngine, FilmFilterPipeline, PreviewRenderer, LivePhotoMovieWriter,
│   │                   Navigator, SessionStore, OrientationLock, CameraMotionService,
│   │                   AppleCredentialChecker, NetworkMonitor, HapticService, ZoomCapabilities,
│   │                   RollRoomService (CloudKit rooms: RollRoomServicing, CloudKitRollRoomService, RollRoomLocation),
│   │                   RollRealtimeService (RollSlotRealtimeProviding, SupabaseRollSlotRealtimeService, NoopRollSlotRealtimeService), SupabaseConfig,
│   │                   RollShotCrypto (AES-GCM shot payload), ScrapbookArchiveSync (restore),
│   │                   CutGeometry, ScrapbookItemLayout, ScrapbookImageLoader, LiveMovieFileCache, LivePlaybackCoordinator, DeletedScrapbookList,
│   │                   ScrapbookLocalDeletionService,
│   │                   DigicamGrade, FilterSamplePhotos (+ FilterSampleRenderer), ProfileAvatarProcessor
│   └── DesignSystem/   Tokens (Color, Typography, Elevation), Components (Button, Icon, Input), Fonts/, ScrapTheme, OffsetPillButtonStyle, CircleIconButton, LivePhotoPlayerView,
│                       DeskCollection/ (DeskCollectionView, DeskEmptyStateView, FolderPreviewCard, RollStripCard),
│                       Scrapbook/ (ScrapbookPageView, ScrapbookItemView, PageBackgroundView, LoopingVideoView, ScrapbookDrawingImage, ViewFrameReader, WashiTapeView, TextItemAppearance, BookSpineArt, BookCoverHingeTransition)
└── Features/
    ├── Auth/           WelcomeSignInView, AuthViewModel
    ├── Home/           WorkbenchView, WorkbenchViewModel, WorkbenchLayout (desk asset frames, portrait & iPad landscape scales), CameraReturnTransitionOverlay,
    │                   Components/ (InteractiveToolboxView, ToolboxEmptyIllustration, InteractiveRollsView, RollEmptyIllustration)
    ├── Profile/        ProfileView, EditProfileView, ProfileViewModel, Components/ (ProfileAvatarView, BookshelfRowView, BookshelfReaderOverlay, ProfileEmptyStateView, ProfileHeaderView, EditProfileFormCard, change 088, 128)
    ├── Roll/           CreateRollSetupView, CreateRollFilterView, CreateRollLobbyView, JoinRollView, CaptureSessionView, CameraIntroTransitionOverlay, CameraIntroHTMLTemplate, RollFlowViewModel, Components/ (InviteFriendSheetView, RollInviteShare, RollAvatarView, RollRoomHeader, FilmStripPickerView, FilterCanisterCardView, KnurledZoomWheelView, CaptureEventView, FilteredCameraPreviewView, ShotsLeftDialView, CameraIrisDiaphragmView, CameraIntroComponents, CameraIntroWebView)
    └── Scrapbook/      ScrapbookEditorView (+ ScrapbookEditorLayout, change 107), ScrapbookViewModel, Components/ (ScrapbookBookView, ScrapbookCoverScreen, BookCoverViews, BookStarCard,
                        BookBackConfirmation, WhosHereSheet, SpreadEditorButton,
                        ScissorsToolView, StickerDragController, StickerSheetOverlay, BackgroundPickerView,
                        TrayStyle, ToolTray (+ iPad floating dockable pill), TrayScroll (+ trayPillWidth), ScrollPanProbe, SubTrays, TrayDragController, PencilController, PencilTray, DrawingCanvasView,
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
- pages and sticker sheets (change 013, this device only); tools whose hint was already shown (change 022); cover color, locked (+ date), pages finished on this phone, members done editing (change 026); cover color picked (change 103: until then the default blue is shown)

### ScrapbookPage (change 013) [Draft]
- order, background, items, role (`nil` page, `front`, `spine`; cover sides stay out of spreads, change 026). Max 40 items (change 022). Shown two per spread (page index / 2); a scrapbook always has an even page count (change 025). The old page drawing field is only read to move it into a layer

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
