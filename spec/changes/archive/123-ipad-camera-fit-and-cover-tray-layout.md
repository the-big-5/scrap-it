# 123: iPad Camera Fit Scaling & Cover/Spine Edit Tray Layout

Status: Done

## Why
1. **iPad Camera UI cropping (`CaptureSessionView.swift`)**:
   - The camera canvas (`cameraCanvas`) uses a fixed `874 × 402` phone frame scaled by `max(viewportWidth / canvasWidth, viewportHeight / canvasHeight)`. On iPad's `4:3` aspect ratio, `max(...)` fills the shorter axis and scales `874` wider than the viewport, clipping the left column (Flash, Back), `LIVE` indicator, and right-side controls/edges.
   - All existing camera functionality, orientation handling (`RollCameraOrientation`), motion tracking (`CameraMotionService`), capture pipeline (`CameraController` / `CameraEngine`), and iPhone layout must remain completely untouched.
2. **iPad Cover & Book Spine Edit tray clipping (`ScrapbookEditorView.swift`)**:
   - In `editCoverView`, `ScrapbookEditorLayout.coverScale(for:)` only subtracts `250` pt from `container.height`, whereas the `VStack` chrome totals `~345` pt on `.front` (top toolbar `~50` pt + `Edit book spine` button margins/height `115` pt + bottom `Spacer(minLength: TrayStyle.trayHeight + 74)` = `180` pt).
   - Because `editCoverView`'s root `ZStack` inside `GeometryReader` has no viewport frame constraint (and contains `.ignoresSafeArea()` on `CoverCuttingMat`), the oversized `VStack` expands the `ZStack` `~95` pt past the bottom of the screen, pushing the bottom-aligned `ToolTray` and `CoverColorButton` off the bottom edge of the iPad screen (and leaving insufficient clearance when a sub-tray opens in either front or spine edit mode across iPad Portrait and Landscape).

## Touches
ui.md (Screen: Capture Session, Screen: Scrapbook)

## Changes
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift` (and optional pure helper on `RollCameraOrientation`):
  - Keep iPhone scaling (`max(viewportWidth / canvasWidth, viewportHeight / canvasHeight)`), `RollCameraOrientation` rotation math, `OrientationLock`, `popupOverlay`, and all `CameraController` / `CameraEngine` / `CameraMotionService` logic completely unchanged.
  - On iPad (`UIDevice.current.userInterfaceIdiom == .pad`), compute `scale` using `min(viewportWidth / canvasWidth, viewportHeight / canvasHeight)` so the full `874 × 402` camera body and every control (`Flash`, `Back`, `LIVE`, viewfinder, zoom wheel, `End Roll`, shutter, flip, `ShotsLeftDialView`) fit proportionally inside both iPad Portrait and iPad Landscape viewports without cropping, centered on the dark matte/leather surround.
- MODIFIED `ScrapIt/Features/Scrapbook/ScrapbookEditorView.swift`:
  - Bound `editCoverView`'s layout container cleanly to `geometry.size` (with `CoverCuttingMat()` kept behind as the full-bleed background) so bottom-aligned overlays (`ToolTray` and `CoverColorButton`) always anchor inside the visible viewport bounds.
  - Add an edit-cover scale calculation on `ScrapbookEditorLayout` (leaving `ScrapbookCoverScreen` scaling intact) that accounts for the actual top bar, `.front` vs `.spine` header (`Edit book spine` button), and bottom clearance (fixed `ToolTray` + `CoverColorButton`, including open sub-tray clearance) on iPad in both Portrait and Landscape orientations.
  - Preserve Cover & Spine Edit's fixed bottom-center `ToolTray` (`pillWidth` = `iPadTrayPillWidth`) and `CoverColorButton` placement without changing iPhone Cover/Spine Edit layout or iPad Spread Editor (`iPadEditLayout`).
- MODIFIED `ScrapItTests/Scrapbook/ScrapbookEditorTests.swift` (and camera orientation/layout test suite):
  - Add unit tests verifying iPad `CaptureSessionView` canvas fit scale (`min`) vs iPhone fill scale (`max`) across portrait and landscape dimensions, and `ScrapbookEditorLayout` edit-cover/spine scaling & vertical bounds clearance across iPad Portrait and Landscape sizes.
- Specs at merge (`/merge-changes`):
  - `ui.md`: Document iPad proportional fit scaling (`min`) for `CaptureSessionView` preserving all camera controls without cropping, and viewport-bounded `editCoverView` / spine scaling cleanly above the fixed bottom-center `ToolTray` on iPad.

## Tasks
- [x] Add an iPad-scoped proportional fit scale helper (`min` on iPad, `max` untouched on iPhone) in `CaptureSessionView.swift` / `RollCameraOrientation.swift` while keeping all existing camera functionality and iPhone layout untouched
- [x] Update `editCoverView` and `ScrapbookEditorLayout` in `ScrapbookEditorView.swift` so the `ZStack` stays bounded to the viewport and front cover + spine scale cleanly above `ToolTray` (main + open sub-tray) and `CoverColorButton` in both iPad Portrait and Landscape
- [x] Add unit tests covering iPad camera fit scaling and iPad cover/spine edit vertical clearance, and verify with `xcodebuild test` on iPad and iPhone simulators

## Out of scope
- Changing any iPhone camera layout, `CameraController`, `CameraEngine`, `CameraMotionService`, or `RollCameraOrientation` capture/rotation logic
- Changing iPad camera `OrientationLock` or introducing a bespoke iPad camera asset layout
- Switching `editCoverView` to the Spread Editor's draggable/dockable side-edge PencilKit tray
- Modifying `ScrapbookCoverScreen` or Spread Editor (`iPadEditLayout`) layout
- Editing main `spec/*.md` files before `/merge-changes`
