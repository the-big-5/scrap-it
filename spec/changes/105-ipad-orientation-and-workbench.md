# 105: iPad Orientation Support & iPad 13" Landscape Workbench
Status: Approved

## Why
Although `ScrapIt.xcodeproj` (`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad`) declares all 4 interface orientations for iPad and `AppDelegate.application(_:supportedInterfaceOrientationsFor:)` delegates to `OrientationLock.mask`, `OrientationLock` currently hardcodes `mask = .portrait`, returns `.portrait` from `mask(isCaptureSessionVisible:)`, and resets to `.portrait` regardless of device idiom. On iPad, the app stays locked in portrait everywhere (outside explicit spread edits).

Additionally, `WorkbenchLayout` currently hardcodes the `402 × 874` iPhone portrait canvas (`scale = container.width / 402`). In iPad 13" landscape (`1376 × 1032` / `1366 × 1024`), `402 × 874` scales by ~`3.42×` to ~`2991` pt tall, severely cropping the desk vertically instead of rendering the dedicated landscape iPad Workbench from Figma `1563:34278` (`IPAD - Home`, `1210 × 834`).

This change restores the iPad orientation & iPad 13" landscape Workbench plan on top of Change `104` (**Option A** scope): making `OrientationLock` device-aware (supporting `.all` on iPad while preserving `.portrait` on iPhone), keeping `CaptureSessionView` explicitly locked to `.portrait` so its `874 × 402` camera canvas cannot clip on iPad rotation, adapting `WorkbenchLayout` + `WorkbenchView` + `CameraReturnTransitionOverlay` to switch cleanly between the `402 × 874` portrait layout (iPhone + iPad Portrait) and the `1210 × 834` iPad landscape layout (`1563:34278`), and preserving Change `104`'s persistent layered [`InteractiveToolboxView`](file:///Users/lepin/Documents/ADA/C7/final-app/ScrapIt/ScrapIt/Features/Home/Components/InteractiveToolboxView.swift) (`DeskToolboxBase` + 8 loose tool sprites → continuous center glide/rattle → **Resume Editing**) and Camera (`Create Roll` / `Join a Roll`) behavior across both orientations.

## Touches
tech.md (Orientation, Assets/Home), ui.md (Screen: Home)

## Changes
- MODIFIED `ScrapIt/Core/Services/OrientationLock.swift`:
  - Add device-aware default orientation helper `static func defaultMask(for idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> UIInterfaceOrientationMask`, returning `.all` for `.pad` and `.portrait` otherwise.
  - Initialize `private(set) static var mask: UIInterfaceOrientationMask = defaultMask()` so iPad launches with `.all` allowed instead of `.portrait`.
  - Update `mask(isCaptureSessionVisible: Bool, idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> UIInterfaceOrientationMask` (preserving 1-argument source compatibility with existing callers/tests) to return `defaultMask(for: idiom)` (`.all` on iPad, `.portrait` on iPhone).
  - Update `resetToPortrait()` to call `set(defaultMask())` (and expose `resetToDefault()` with a clear doc comment) so `.onDisappear` / lobby exits / `RollFlowViewModel` restore `.all` on iPad and `.portrait` on iPhone.
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift` (**Option A** portrait guard):
  - Call `OrientationLock.set(.portrait)` on `.onAppear` instead of `OrientationLock.resetToPortrait()`, keeping the `874 × 402` fixed-canvas Capture Session safely portrait-locked on both iPhone and iPad while `.onDisappear`, "Open Scrapbook", and `RollFlowViewModel` exits continue calling `resetToPortrait()` to restore `defaultMask()` (`.all` on iPad).
- MODIFIED `ScrapIt/Features/Home/WorkbenchLayout.swift`:
  - Introduce `WorkbenchVariant` (`portrait`, `iPadLandscape`) selected from device idiom + container aspect (`idiom == .pad && container.width > container.height`, overridable for unit tests).
  - **`.portrait` (`designSize = CGSize(width: 402, height: 874)`):** Keep all existing portrait desk placements, `086`/`100` camera zoom/return formulas, and Change `104`'s toolbox constants (`toolboxSize = 311.944 × 416.129`, `toolboxIdleCenter = (264.558, 200.304)`, `toolboxActiveCenter = (192.756, 450.046)`, `toolboxIdleRotation = -70.96°`, `toolboxActiveRotation = -89.62°`, `toolboxActiveScale = 281.595 / 311.944`) intact for iPhone and iPad Portrait.
  - **`.iPadLandscape` (`designSize = CGSize(width: 1210, height: 834)`, Figma `1563:34278`):**
    - Scale uniformly by width (`scale = container.width / 1210`, `origin = CGPoint(x: 0, y: (container.height - 834 * scale) / 2)`), keeping `1210 × 834` 1:1 and scaling cleanly on 13" iPad (`1376 × 1032` → `scale ≈ 1.137`, `origin.y ≈ 41.8`; `1366 × 1024` → `scale ≈ 1.129`, `origin.y ≈ 41.2`).
    - Define `1210 × 834` placements and rotations matching Figma `1563:34278`:
      - Green cutting mat frame (`1563:34283`: `x: 0, y: 91, width: 1210, height: 652`).
      - Blue bottom notebook (`1563:34908`, `buku bawah 1`, new unclipped `DeskBookBottomLandscape` rotated `-24.38°`), spiral orange Tutorial notebook (`1563:34915`, reusing `DeskBookTutorial` rotated `-9.26°`), and the 3 decorative film canisters reusing `DeskFilmRoll2` (`400 36`), `DeskFilmRoll3` (`COLOR 100`), and `DeskFilmRoll4` (`200`) aligned to `1563:34278`.
      - Layered interactive red Toolbox (`1563:34910`, `stat 1`): reuses Change `104`'s `InteractiveToolboxView` (`DeskToolboxBase` + 8 loose tool sprites) scaled cleanly to Figma `1563:34910` unrotated size `CGSize(width: 510.146, height: 680.527)`, idle center `CGPoint(x: 888.849, y: 253.102)`, idle rotation `-70.96°`, and centered active state (`center: (605, 417)`, `rotation: -89.62°`, `activeScale: 380 / 510.146 ≈ 0.745` so the opened box stays centered with comfortable vertical clearance inside the `834` pt frame).
      - Disposable camera (`1563:34914`, `dispo 1`, reusing `DeskDisposableCamera`): size `CGSize(width: 471.433, height: 353.402)`, idle center `CGPoint(x: 400.375, y: 258.428)`, idle rotation `-2.91°`; active camera center `CGPoint(x: 605, y: 270)` rotated `0.77°`.
      - Active camera menu action buttons ("Create Roll" / "Join a Roll"): `actionButtonSize = CGSize(width: 260, height: 58)` (capsule + `7` pt ink offset shadow, matching portrait proportions) centered at `CGPoint(x: 605, y: 550)`.
    - Expose active-variant accessors (`activeToolboxSize`, `activeToolboxIdleCenter`, `activeToolboxActiveCenter`, `activeToolboxIdleRotation`, `activeToolboxActiveRotation`, `activeToolboxActiveScale`, `activeCameraSize`, `activeCameraIdleCenter`, `activeCameraActiveCenter`, `activeCameraIdleRotation`, `activeCameraActiveRotation`, `activeActionButtonsCenter`, `activeActionButtonSize`) and pass active `cameraSize` cleanly into `zoomedCameraScale` / `fullBleedCameraScale` / `floatingCameraScale` so `086`/`100` camera return transitions support `.iPadLandscape`.
- MODIFIED `ScrapIt/Features/Home/WorkbenchView.swift` & `ScrapIt/Features/Home/CameraReturnTransitionOverlay.swift`:
  - Instantiate `WorkbenchLayout` using the current container size + device idiom (`.iPadLandscape` when `UIDevice.current.userInterfaceIdiom == .pad && proxy.size.width > proxy.size.height`, otherwise `.portrait`).
  - Render the iPad landscape Workbench (`1563:34278`):
    - Full-bleed landscape wood desk background (`DeskWoodLandscape`, scaled `.fill` behind the centered frame) so the top/bottom ~`41.8` pt extension on 13" iPad (`1376 × 1032`) shows continuous natural wood rather than flat color bars, with unclipped edge-bleeding `DeskBookBottomLandscape` and `InteractiveToolboxView` extending cleanly without mid-wood cut lines.
    - Full-width `1210 × 652` cutting mat surface drawn in SwiftUI (`#2D7757` / `#2D7758` / `#206E50` radial gradient + subtle inset shadow + translucent mat texture ellipses), crisp `44` pt square white grid lines, and top/bottom `1...27` measurements & ticks (fixing Figma's duplicate `"25"` label to `"24"`).
    - Layer desk objects back-to-front per `1563:34278` (reusing `InteractiveToolboxView`, `DeskDisposableCamera`, `DeskBookTutorial`, `DeskFilmRoll2`, `DeskFilmRoll3`, `DeskFilmRoll4`, and substituting only `DeskWoodLandscape` + `DeskBookBottomLandscape` where the iPhone exports are portrait-cropped).
  - Preserve Change `104` & Camera interactions consistently across `.portrait` and `.iPadLandscape`:
    - Tapping `InteractiveToolboxView` hides the tab bar, blurs/dims the desk, glides and scales the toolbox continuously to `layout.point(layout.activeToolboxActiveCenter)` with interior-tool rattle (`playToolboxRattle()`) + haptics (`viewModel.activateToolbox()`), and pushes `"Resume Editing"` (`.deskCollection(.scrapbooks)`).
    - Tapping the spiral `"Tutorial"` book triggers `viewModel.openTutorial()` (existing stub, disabled while `viewModel.isCameraActive || viewModel.isToolboxActive`).
    - Tapping Camera toggles `viewModel.isCameraActive`, blurring/dimming the desk, spring-gliding camera to center, presenting `"Create Roll"` / `"Join a Roll"`, and showing top-left `BackCircleButton` (`"Close"`).
  - Update `CameraReturnTransitionOverlay.swift` to use `layout.activeCameraSize`, `layout.point(layout.activeCameraIdleCenter)`, and `layout.activeCameraIdleRotation` so returning from Capture Session lands cleanly on the iPad landscape camera idle spot.
  - Omit the empty Figma template `Toolbar` (`1563:34280`) and keep `MainShellView`'s native `TabView` (`088`) unchanged.
- ADDED `ScrapIt/Assets.xcassets/Workbench/` (only 2 new landscape assets needed; `DeskToolboxBase` + 8 tools, `DeskDisposableCamera`, `DeskBookTutorial`, and `DeskFilmRoll2..4` are reused):
  - `DeskWoodLandscape` (`1563:34282`, cropped clean of the left cactus so 13" landscape doesn't stretch `DeskWood` `1206` px vertical strip `> 2.2×`).
  - `DeskBookBottomLandscape` (`1563:34908` unclipped `buku bawah 1`, because existing `DeskBookBottom` has its left spine sliced flat along `x = 0`).
- MODIFIED `ScrapItTests/Home/WorkbenchLayoutTests.swift`, `ScrapItTests/Camera/CameraBehaviorTests.swift`, `ScrapItTests/Roll/RollRoomTests.swift`:
  - Add `WorkbenchLayoutTests` coverage for `.iPadLandscape` (`1210 × 834` 1:1 mapping, `1376 × 1032` & `1366 × 1024` 13" iPad uniform width scale, vertical centering, object placements, active toolbox idle/center bounds, camera return scale targets) and iPad Portrait (`1032 × 1376`, `1024 × 1366`) fallback to `.portrait`.
  - Update `CameraBehaviorTests` and `RollRoomTests` to assert `OrientationLock.defaultMask()` on exit and explicitly test `OrientationLock.defaultMask(for: .pad) == .all`, `defaultMask(for: .phone) == .portrait`, and `mask(isCaptureSessionVisible: ..., idiom: ...)` so tests pass on both iPhone and iPad simulators.
- Specs at merge (`/merge-change`):
  - `tech.md` (Orientation): record `.all` orientation support on iPad while iPhone stays `.portrait`.
  - `ui.md` (`Screen: Home`, `Assets`): document the iPad landscape `1210 × 834` Workbench (`1563:34278`), its `.portrait` fallback (`402 × 874`), and `DeskWoodLandscape` / `DeskBookBottomLandscape`.

## Tasks
- [x] Export and add the 2 unclipped iPad landscape assets (`DeskWoodLandscape`, `DeskBookBottomLandscape`) from Figma `1563:34278` into `ScrapIt/Assets.xcassets/Workbench/`, reusing `InteractiveToolboxView` (`DeskToolboxBase` + 8 tools), `DeskDisposableCamera`, `DeskBookTutorial`, `DeskFilmRoll2`, `DeskFilmRoll3`, and `DeskFilmRoll4`
- [x] Update `OrientationLock.swift` for device-aware `.all` default/reset on iPad and `.portrait` on iPhone, and update `CaptureSessionView.swift` `.onAppear` to call `OrientationLock.set(.portrait)` (**Option A**) so Capture Session stays portrait-locked on iPad without touching `RollFlowViewModel.swift` or the camera UI layout
- [x] Extend `WorkbenchLayout.swift` with `.iPadLandscape` (`1210 × 834`) constants/scaling alongside `.portrait` (`402 × 874`), active-variant accessors (including toolbox & camera idle/active geometry), and camera sizing for `086`/`100` transitions
- [x] Update `WorkbenchView.swift` and `CameraReturnTransitionOverlay.swift` to switch between `.portrait` (`402 × 874`) and `.iPadLandscape` (`1563:34278`) layouts, draw the `1...27` cutting mat grid/measurements in SwiftUI vector, reuse `InteractiveToolboxView` (`activateToolbox()` → **Resume Editing**) and existing unclipped assets cleanly
- [x] Add/update unit tests in `WorkbenchLayoutTests.swift`, `CameraBehaviorTests.swift`, and `RollRoomTests.swift`, and run `xcodebuild test` across both iPhone and iPad 13" simulators

## Out of scope
- Redesigning `CaptureSessionView.swift` for iPad landscape, or modifying `RollFlowViewModel.swift` or camera UI/capture math (Capture Session remains explicitly portrait-locked via `OrientationLock.set(.portrait)`)
- Modifying `ScrapbookEditorView.swift`'s explicit `OrientationLock.set(.portrait)` behavior when `!allowsLandscape` or adapting other screens (`Resume Editing` / `Profile` / `Roll Setup` / `Filter` / `Lobby` / `Join` / `Roll Reveal` / `Onboarding` / `Welcome`) for custom iPad layouts
- Rendering the empty Figma `Toolbar` (`1563:34280`) or modifying `MainShellView`'s native `TabView` (`088`)
- Designing a separate custom iPad Portrait Workbench layout (iPad Portrait reuses the existing `402 × 874` layout)
- Making the film canisters or blue bottom notebook interactive, or implementing the tutorial flow beyond `openTutorial()` stub
- Modifying `ScrapIt.xcodeproj` settings (`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` already includes all 4 orientations)
