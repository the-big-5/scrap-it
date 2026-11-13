# 129: Workbench Layout Redesign & Unused Assets Cleanup

Status: Approved

## Why
- The design team updated the Portrait Workbench idle layout (Figma `1766:57249`) and active Camera Click state (Figma `1766:57454`), repositioning the camera to the top of the mat, the toolbox to the lower right, and the three film canisters to a left-center cluster while decluttering background props.
- Camera Click (`1766:57454`) also updates the action overlay: dark charcoal `#2A241F` capsule buttons instead of white offset-shadow pills, no top-left `✕` button, and a visible Tab Bar beneath the blurred desk while remaining desk items keep their idle coordinates.
- Eight portrait desk props removed from the new design plus four already-unreferenced legacy imagesets remain in `Assets.xcassets/Workbench/`.

## Touches
ui.md (Screen: Home [Locked], Screen: Camera Roll, Assets)

## Changes
- MODIFIED `ScrapIt/ScrapIt/Features/Home/WorkbenchLayout.swift`:
  - Update Portrait (`402 × 874`, Figma `1766:57249` / `1766:57454`) coordinates and sizes while leaving iPad Landscape (`1210 × 834`) completely untouched:
    - Remove `DeskRuler`, `DeskPaperBall1`, `DeskPaperBall2`, and `DeskStationery1`–`DeskStationery5` from `deskItems`, retaining the desk wood, cutting mat layers, `DeskBookBottom`, and `DeskBookTutorial`.
    - Reposition Portrait camera (`DeskDisposableCamera`): `idleCenter = (201.301, 173.469)` with `idleSize = (345.921, 259.314)` at `-14.77°`; `activeCenter = (152.13, 335.149)` with `activeSize = (291.357, 218.411)` at `0.77°` (splitting `cameraIdleSize` and `cameraActiveSize` where needed so both idle and active frames match Figma).
    - Reposition Portrait toolbox (`InteractiveToolboxView`) to `idleCenter = (320.558, 548.304)` (rotated `-70.96°` / scaled to match `stat 1` in `1766:57249`), and update Portrait film canisters (`DeskFilmRollYellow` at `(142.5, 365)`, `DeskFilmRollGreen` at `(115.034, 444.516)` rotated `46.7°`, `DeskFilmRollRed` at `(51.995, 389.874)` rotated `54.26°`).
    - Update `actionButtonsCenter` to `(153.5, 487)` with button size `217 × 52` and `16` pt vertical spacing (`1766:57454`).
  - Adjust iPad Portrait (`idiom == .pad && height > width`, ~3:4 aspect ratio) layout transform/positioning so the top-positioned camera (`y = 4...343`), lower-right toolbox (`y = 333...764`), film canisters, tutorial book, and active Camera Click buttons fit comfortably inside iPad Portrait viewports without top/bottom edge clipping, while keeping iPhone Portrait pixel-exact to `402 × 874`.
- MODIFIED `ScrapIt/ScrapIt/Features/Home/WorkbenchView.swift`:
  - Remove the top-left `xmark.circle.fill` close button when `viewModel.isCameraActive`; tapping the blurred desk backdrop continues to dismiss the camera menu.
  - Replace the obsolete inline `#FEFEFD` + 7pt offset shadow styling in `actionButton` with solid `#2A241F` (`DSColor.Brand.primary`) capsule buttons and `#FCFBF9` (`DSColor.Kraft.light`) 22pt Bold SF Pro labels per Figma `1766:57454` (keeping `OffsetPillButtonStyle.swift` intact for other screens that still use it).
  - Animate/interpolate camera size cleanly between `idleSize` and `activeSize` during Camera Click expansion/collapse, and ensure all non-camera desk objects keep their exact idle coordinates behind the blur.
- MODIFIED `ScrapIt/ScrapIt/Features/Home/WorkbenchViewModel.swift` (& `MainShellView.swift` if needed for Tab Bar overlay behavior):
  - Keep the Tab Bar visible during `isCameraActive` (instead of hiding it alongside `isToolboxActive` / `isRollsActive`) per Figma `1766:57454` (documenting or applying blur/dimming behavior over the tab bar region where `TabView` allows).
- MODIFIED `ScrapIt/ScrapIt/Features/Home/CameraReturnTransitionOverlay.swift`:
  - Ensure return-to-mat settle animation targets the new Portrait `idleCenter` and `idleSize` without visual jumps.
- REMOVED unused `.imageset` folders from `ScrapIt/ScrapIt/Resources/Assets.xcassets/Workbench/`:
  - Removed portrait desk props: `DeskRuler.imageset`, `DeskPaperBall1.imageset`, `DeskPaperBall2.imageset`, `DeskStationery1.imageset`, `DeskStationery2.imageset`, `DeskStationery3.imageset`, `DeskStationery4.imageset`, `DeskStationery5.imageset`.
  - Unreferenced legacy workbench assets: `DeskToolbox.imageset`, `DeskFilmRoll2.imageset`, `DeskFilmRoll3.imageset`, `DeskFilmRoll4.imageset`.
- MODIFIED `ScrapIt/ScrapItTests/Home/WorkbenchLayoutTests.swift`:
  - Update Portrait idle/active camera, toolbox, roll canister, and action-button assertions to the new `1766:57249` / `1766:57454` geometry, and add assertions verifying iPad Portrait fit (no top/bottom clipping) alongside unchanged iPad Landscape coverage.
- MODIFIED `ScrapIt/spec/ui.md` (at `/merge-change`):
  - Update `Screen: Home [Locked]`, `Screen: Camera Roll`, and `Assets` to reference Figma `1766:57249` and `1766:57454` and remove deleted workbench assets.

## Tasks
- [ ] Update Portrait layout constants, separate idle vs. active camera sizes, remove obsolete portrait desk props, and add iPad Portrait non-clipping fit logic in `WorkbenchLayout.swift` (keeping iPad Landscape untouched).
- [ ] Update `WorkbenchView.swift` Camera Click UI (dark `#2A241F` capsule buttons with `#FCFBF9` text, remove inline white/offset button styling, remove top-left close `✕` button, animate camera `idleSize` ↔ `activeSize`).
- [ ] Keep Tab Bar visible during `isCameraActive` in `WorkbenchViewModel.swift` / `MainShellView.swift` and verify `CameraReturnTransitionOverlay.swift` lands smoothly on the new idle camera spot.
- [ ] Delete the 12 unused `.imageset` folders from `Assets.xcassets/Workbench/` and verify no dangling references remain.
- [ ] Update `WorkbenchLayoutTests.swift` and run `xcodebuild test` + verify Portrait (iPhone & iPad) and iPad Landscape builds cleanly.

## Out of scope
- Changing iPad Landscape (`1210 × 834`, `1563:34278`) workbench positions or assets.
- Deleting `OffsetPillButtonStyle.swift` (still used by `CreateRollLobbyView`, `InviteFriendSheetView`, `OnboardingSlidesView`, `RollRevealView`, and `RevealPhotoViews`).
- Redesigning Toolbox click (`1230:20656`) or Rolls click (`1235:21168`) animations/layouts beyond updated Portrait idle origin coordinates.
