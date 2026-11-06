# 010: Remove the unreachable Camera Roll menu screen
Status: Done

## Why
Since the Workbench popup (Create Roll / Join a Roll on the camera) replaced it, nothing pushes `.cameraRollMenu`, so `CameraRollMenuView` can never be opened. It and its desk background `DeskSurface` (7.4 MB) are dead code and dead weight. Recorded as [Open] at the 009 merge.

## Touches
ui.md (Assets), tech.md (Code structure)

## Changes
- REMOVED `Features/Roll/CameraRollMenuView.swift`
- REMOVED `Features/Home/Components/DeskSurfaceView.swift` (only used by `CameraRollMenuView`) and the empty `Components/` folder if nothing else is in it
- REMOVED asset `DeskSurface` (7.4 MB)
- REMOVED route `AppRoute.cameraRollMenu` (`Navigator.swift`) and its case in `MainTabView`
- UNCHANGED: `HeroCamera` (still used by the Welcome screen via `RetroCameraIllustration`); the Workbench popup flow; ui.md "Screen: Camera Roll (Create / Join)" already says it is integrated into the Workbench popup
- ui.md at merge: drop the `DeskSurface` [Open] line from Assets
- tech.md at merge: drop `CameraRollMenuView` and `Components/ (DeskSurfaceView)` from Code structure

## Tasks
- [x] Delete the files, asset and route above
- [x] Build and run all tests on Simulator (85 tests pass, 1 known issue from 003)
- [x] Quick check: Workbench → camera → Create Roll / Join a Roll still work (user confirmed)

## Out of scope
- Any other screen or asset

## Implementation findings
- The empty `Features/Home/Components/` folder disappeared with `DeskSurfaceView`
- App size: about 7.4 MB less (`DeskSurface`)
