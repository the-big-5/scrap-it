# 104: Workbench Toolbox Transition & Composable Resume Editing Screen
Status: Done

## Why
On the Home Workbench (`WorkbenchView`), `DeskToolbox` is currently a static desk illustration while `DeskDisposableCamera` opens the roll flow. Making `DeskToolbox` interactive turns it into the entry point for resuming existing scrapbooks, built with composable UI primitives so upcoming desk flows (such as `Resume Roll`, Figma `1537:25997`) can reuse the exact same screen shell, empty-state layout, and card components:
1. Tapping `DeskToolbox` blurs and dims the desk, hides the tab bar (`navigator?.isTabBarHidden`), and lifts/centers the open red toolbox (`stat 1`, Figma `1230:20656` / `1230:20860`) with a lively shake/rattle animation and haptic feedback, then automatically navigates to **"Resume Editing"**.
2. **"Resume Editing"** (`1537:25855`) shows all local `Scrapbook`s (newest first) in a 2-column grid of tactile folder cards styled with the 3 Figma folder themes (cycling Burgundy, Kraft/Tan, Navy/Slate in order), formatted `dd/MM/yyyy` creation dates, and `1...4` real photo previews from that scrapbook's roll peeking out of each folder (deterministic/stable per `scrapbook.id`; `0` when a scrapbook has no photos).
3. Tapping a folder opens `ScrapbookEditorView`; long-pressing a folder allows removing it from this device only (clearing local SwiftData + cached Live Photo movies and recording `DeletedScrapbookList`, while keeping the shared CloudKit copy intact for collaborators).
4. When there are no local scrapbooks, **"Resume Editing"** displays the empty state (`1537:25830`) with the craft illustration, `"No scrapbook in progress...yet!"`, `"Every scrapbook starts with a roll. Gather your friends and capture moments together."`, and a `"Create Roll"` primary pill button (`DSButton`) that navigates directly to `CreateRollSetupView`.
5. The collection screen is composed from reusable, data-agnostic UI building blocks in `Core/DesignSystem/DeskCollection/` (`DeskCollectionView`, `DeskEmptyStateView`, `FolderPreviewCard`) so future screens like `"Resume Roll"` (`1537:25997`) can compose the same shell, empty-state layout, and folder/item grids without refactoring or duplication.

## Touches
flows.md (F5: Scrapbook creation), ui.md (Screen: Home, Screen: Resume Editing), tech.md (Code structure)

## Changes
- ADDED `ScrapIt/Assets.xcassets/`:
  - `Workbench/DeskToolboxBase.imageset` and 8 loose tool sprites (`DeskToolboxRuler`, `DeskToolboxPencils`, `DeskToolboxCutter`, `DeskToolboxScissors`, `DeskToolboxEraser`, `DeskToolboxTapePink`, `DeskToolboxTapeBlue`, `DeskToolboxNotes`) derived from Figma `920:3092` / `1230:20860` (`stat 1`) so the toolbox lid/tray and each tool inside can animate cleanly together.
  - `DeskCollection/` folder `Back`, `Flap`, and `EdgeHighlight` assets for the 3 Figma folder color themes (Burgundy, Kraft/Tan, Navy/Slate) from `1537:25855`, plus the empty-state craft illustration assets from `1537:25830` (`ToolboxEmptyNotebook`, `ToolboxEmptyPencil`, `ToolboxEmptyRuler`, `ToolboxEmptyScissors`, `ToolboxEmptyStarburst`, `ToolboxEmptyPhotoBack`, `ToolboxEmptyPhotoFront`).
- ADDED `ScrapIt/Core/Services/ScrapbookLocalDeletionService.swift`:
  - Shared local-only deletion helper (extracted from `ProfileViewModel.confirmDelete()`) that records `sourceSessionID` in `DeletedScrapbookList`, deletes the local `Scrapbook`, its `ScrapPhoto`s, and its local `CaptureSession` from `ModelContext`, saves, and removes cached Live Photo files via `LiveMovieFileCache` without altering CloudKit shared data.
- MODIFIED `ScrapIt/Features/Profile/ProfileViewModel.swift`:
  - Delegate `confirmDelete()` to `ScrapbookLocalDeletionService` to avoid duplicated local deletion logic.
- ADDED `ScrapIt/Core/DesignSystem/DeskCollection/`:
  - `DeskCollectionView.swift`: Reusable `DSColor.Kraft.lightActive` screen container with top `BackCircleButton` + centered title header, switching cleanly between `@ViewBuilder content` (populated scrollable grid/list) and `@ViewBuilder emptyState`.
  - `DeskEmptyStateView.swift`: Reusable empty-state layout matching Figma `1537:25830` / `1537:25997`, parameterized with `@ViewBuilder illustration`, `title`, `message`, `actionTitle`, and `onAction` (`DSButton(..., variant: .primary, size: .large)`).
  - `FolderPreviewCard.swift`: Reusable Figma folder card component + `FolderCardTheme` (`.burgundy`, `.kraft`, `.navy`) + `FolderPreviewPhoto`, rendering `Back` + `0...4` angled/tucked photo previews + `Flap` + `EdgeHighlight`, `title`, and `subtitle` (`dd/MM/yyyy`), decoupled from `Scrapbook` / SwiftData models so any feature can bind its own item data and tap/context actions.
- MODIFIED `ScrapIt/App/Navigation/NavigationRoutes.swift`:
  - Add `DeskCollectionKind` (`case scrapbooks`) and `case deskCollection(DeskCollectionKind)` to `AppRoute` (`isRollRoute == false`).
- MODIFIED `ScrapIt/App/MainShellView.swift`:
  - Hold `@State private var workbenchViewModel: WorkbenchViewModel` at the shell level (matching `profileViewModel`) and inject it into `Tab("Craft", ...)` -> `WorkbenchView(viewModel: workbenchViewModel)` while preserving `088`'s native `TabView`, `CameraReturnTransitionOverlay` (`086`/`100`), and `isFadingToReveal`.
  - Map `.deskCollection(.scrapbooks)` in `destinationView(for:)` to `"Resume Editing"` composing `DeskCollectionView`, 2-column `FolderPreviewCard` grid, local removal confirmation dialog, and `DeskEmptyStateView` with `ToolboxEmptyIllustration`.
- MODIFIED `ScrapIt/Features/Home/WorkbenchLayout.swift`:
  - Remove `DeskToolbox` from static `deskItems` so it lives as one persistent interactive element on the desk (`toolboxSize = 311.944 × 416.129`), placing `toolboxIdleCenter` (`264.558, 200.304`) and `toolboxIdleRotation` (`-70.96°`) from Figma `920:3092` (`853:1703`).
  - Add `toolboxActiveCenter` (`192.756, 450.046`), `toolboxActiveRotation` (`-89.62°`), and `toolboxActiveScale` (`281.595 / 311.944`) from Figma `1230:20860` (`1230:20656`).
  - Keep all `086`/`100` camera return zoom/flip metrics intact.
- MODIFIED `ScrapIt/Features/Home/WorkbenchViewModel.swift`:
  - Add `isToolboxActive` (hiding the native tab bar via `navigator?.isTabBarHidden` while active), guard against overlapping camera/toolbox activation, and drive `activateToolbox()` → ~`0.90`s glide + shake/rattle delay → reset `isToolboxActive = false` & `navigator?.push(.deskCollection(.scrapbooks))` (with `cancelToolboxTransition()` for view disappearance).
  - Expose helpers for `"Resume Editing"`: `folderTheme(at:)`, `previewPhotos(for:)` (seeded deterministically by `scrapbook.id` to pick `1...min(4, photos.count)` real photos, or `0` if empty), `formattedDate(for:)` (`dd/MM/yyyy`), `startCreateRollFromCollection()` (`navigator?.setStack([.createRollSetup])`), `closeCollection()`, and local-only removal state (`scrapbookPendingRemoval`, `requestRemoveFromDevice(_:)`, `confirmRemoveFromDevice()`).
- ADDED `ScrapIt/Features/Home/Components/InteractiveToolboxView.swift` and MODIFIED `ScrapIt/Features/Home/WorkbenchView.swift`:
  - Render a single persistent `InteractiveToolboxView` button on the desk (behind `camera` when idle; smoothly spring-gliding, rotating, and scaling from its resting corner to `toolboxActiveCenter` above the blurred/dimmed desk & obscured camera when `isToolboxActive`, matching Figma `1230:20656`), while preserving `086`/`100` `cameraReturnPhase` visibility/disabled gating on `camera`.
  - Play a rhythmic rattle (`ToolboxRattleState` + `playToolboxRattle()`) where both the toolbox and the 8 loose stationery tools inside follow with secondary inertia within their compartments (respecting `accessibilityReduceMotion`) alongside tactile haptics via `HapticService`, then transition to `"Resume Editing"`; cancel pending transition in `.onDisappear`.
- ADDED `ScrapIt/Features/Home/Components/ToolboxEmptyIllustration.swift`:
  - Collage illustration (`1537:25830`) rendered inside `DeskEmptyStateView` when `scrapbooks.isEmpty`.
- MODIFIED `ScrapItTests/Home/WorkbenchLayoutTests.swift` and ADDED `ScrapItTests/Home/WorkbenchViewModelTests.swift`:
  - Keep `everyDeskAssetIsUniqueAndInsideTheFrame` checking `deskItems + [tutorialBook]` and replace with `toolboxIdleAndActiveCentersSitInsideDesignFrame` alongside existing `086`/`100` tests.
  - Add `WorkbenchViewModelTests` covering toolbox activation/guarding/cancellation, stable `1...4` (and `0` empty) preview photo selection per `scrapbook.id`, cycling 3-color folder themes, empty-state `"Create Roll"` / `closeCollection()` routing, and local-device removal preserving `DeletedScrapbookList` (using current `CaptureSession(id:name:rollCode:hostUserID:participantIDs:participantNames:rollSize:filter:status:)` with `.colorPrint200`).
- Specs at merge (`/merge-change`):
  - `flows.md` (F5), `ui.md` (Screen: Home, Screen: Resume Editing), `tech.md` (Code structure).

## Tasks
- [x] Download and add Figma assets for the layered open toolbox (`DeskToolboxBase` + 8 loose tool sprites from `1230:20860`), 3-theme folder layers (`1537:25855`), and empty-state craft illustration (`1537:25830`) into `Assets.xcassets`
- [x] Extract shared local-only scrapbook deletion into `ScrapbookLocalDeletionService.swift` and update `ProfileViewModel.swift` to use it
- [x] Build composable DesignSystem primitives in `Core/DesignSystem/DeskCollection/`: `DeskCollectionView.swift`, `DeskEmptyStateView.swift`, and `FolderPreviewCard.swift`
- [x] Add `.deskCollection(DeskCollectionKind)` route to `NavigationRoutes.swift` and share `WorkbenchViewModel` + `"Resume Editing"` destination from `MainShellView.swift`
- [x] Update `WorkbenchLayout.swift`, `WorkbenchViewModel.swift`, `InteractiveToolboxView.swift`, and `WorkbenchView.swift` with one persistent toolbox gliding continuously from desk corner to center, interior tool rattle/shake animation (~0.90s with haptics & Reduce Motion support), and auto-navigation to `.deskCollection(.scrapbooks)` while preserving `086`/`100` camera return behavior
- [x] Build `ToolboxEmptyIllustration.swift` for the empty `"Resume Editing"` state in `MainShellView`
- [x] Update `WorkbenchLayoutTests.swift` and add `WorkbenchViewModelTests.swift`, then run unit tests on iOS Simulator and verify UI visually

## Out of scope
- Implementing the `DeskFilmRoll` click interaction, `"Resume Roll"` screen (`1537:25997`), or its illustration assets (`104` only builds the reusable `Core/DesignSystem/DeskCollection/` primitives that `"Resume Roll"` will later compose)
- Implementing the `DeskBookTutorial` (`openTutorial()`) flow
- Modifying `ScrapbookEditorView` / `ScrapbookViewModel` tools, layout, sync, or `goBack()` behavior
- Adding a completed vs. in-progress status flag to `Scrapbook` or deleting CloudKit roll rooms for collaborators
- Modifying `ProfileView`'s bookshelf & `Edit Cover` spines (`088`/`103`) or adding iPad orientation/layout changes (`093`)
