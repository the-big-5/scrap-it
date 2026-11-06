# 009: Workbench from separate assets, close button, swipeable tab bar
Status: Done

## Why
The Workbench (Home) is one flattened full-screen PNG exported from Figma (`WorkbenchBackgroundIdle`, 5.8 MB). It has the Figma status bar (Dynamic Island) and the blurred tab bar strip printed into it. The tutorial book is an invisible tap area over the picture. The camera and buttons are positioned with separate X/Y scaling, so they drift from the picture on other screen sizes. Several old assets and components are unused, and the tutorial book asset is from an older design.

In Figma every object on the desk is already its own image layer, so each can be exported whole (nothing cut) and placed in the app.

## Touches
ui.md (Home, Assets), tech.md (Code structure: Home components)

## Figma source
File `ujlkuWobqxyvtQwh5plhGF`: Home (Idle) 853:1703, CameraClick 1062:3371

| Asset (app name) | Figma layer |
| :--- | :--- |
| `DeskWood` | `image 7` (884:6451), wood desk photo |
| `DeskShading` | `Desk surface shading · editable` (867:1689) |
| `DeskWoodGrain` | `Wood grain desk texture · editable` (868:1689), without the hidden film roll layer |
| `DeskMatShadow` | `Mat viewport foundation · preserved` (853:1732) |
| `DeskCuttingMat` | `Home trial · cutting mat` (867:1696): mat, grid, texture |
| `DeskMeasurements` | `Top and bottom measurements · editable` (867:1737): numbers and ticks |
| `DeskToolbox` | `stat 1` (920:3092) |
| `DeskFilmRoll2/3/4` | `rolls buatan sanny 2/3/4 1` (939:3099, 939:3098, 939:3097) |
| `DeskBookBottom` | `buku bawah 1` (942:3104) |
| `DeskBookTutorial` | `buku atas 3 1` (1062:3369), new spiral "TUTORIAL" book |
| `DeskRuler` | ruler (944:3121) |
| `DeskPaperBall1/2` | crumpled paper (944:3116, 944:3118) |
| `DeskStationery1–5` | `flat-lay-assortment… 1–5` (977:3133, 977:3135, 977:3136, 977:3137, 977:3138) |
| `DeskDisposableCamera` | `dispo 2` (1062:3575), straight camera, rotated in code |

Not exported: Status Bar, Tab Bar, Toolbar (built in code), hidden layers (853:1984 toolbox illustration, 853:1853 film roll).

## Changes
- MODIFIED Home Workbench is built from separate assets, each exported whole from Figma (PNG @1x/@2x/@3x, transparent where the object has a shape). Nothing is cut inside the asset; objects that bleed past the screen edge in Figma bleed the same way in the app
- ADDED asset folder (user request at approval): all Workbench-only assets go in one asset catalog folder `Assets.xcassets/Workbench/` (no namespace, names unchanged). Assets likely reused elsewhere stay at the catalog root: `DeskDisposableCamera` (the app's camera)
- MODIFIED layout: one uniform scale from the Figma frame (402 pt wide = screen width), the 402×874 desk centered vertically; the wood desk fills the whole screen behind it. Taller phones show more wood at top and bottom, shorter phones less. Objects keep their Figma position, size and rotation (no separate X/Y stretching)
- REMOVED from the background: the Figma status bar / Dynamic Island and the blurred tab bar strip (they were printed into the old PNG). The app's real status bar and floating tab bar are used
- MODIFIED tutorial book: new spiral "TUTORIAL" book from Figma; the book image itself is the tap target (was an invisible area). Tap still calls `openTutorial()` (open stub, unchanged)
- UNCHANGED camera behavior: tapping the camera keeps the current spring animation (moves to center while rotating from -14.77° to 0.77°, shadow grows), desk blurs and dims, "Create Roll" / "Join a Roll" text buttons spring up from the bottom with the current style. Tapping the blurred desk still closes it
- ADDED close button in the camera-active state (Figma CameraClick "Toolbar - Top", leading): round white button with a back chevron at top left; closes the same way as tapping the blur. Exact look from Figma at implementation
- MODIFIED floating tab bar (Home | Explore | Profile): besides tapping, the user can drag along the bar; the selection pill follows the finger and snaps to the nearest tab on release, with a light haptic when it passes a tab (like the native iOS tab bar). Look unchanged
- REMOVED unused code and assets:
  - `WorkbenchBackgroundIdle`, `WorkbenchBackgroundActive` (~10.7 MB)
  - `DeskDecorationsView`, `CuttingMatView`, `DisposableCameraView` (not used anywhere)
  - Old `Desk*` assets replaced by the new exports or no longer used: `DeskFolder`, `DeskTape1`, `DeskTape2`, `DeskBookTop` (and old versions of the names reused above)

## Tasks
- [x] Read exact positions, sizes, rotations and shadows per layer from Figma (`get_design_context`, read-only); do not invent values
- [x] Download each asset from Figma at @1x/@2x/@3x into `Assets.xcassets/Workbench/` with the names above (`DeskDisposableCamera` at the root)
- [x] `WorkbenchView`: desk canvas 402×874 with uniform scale by screen width, centered vertically; wood fills the screen; place every asset; blur and dim the whole desk (not the camera) in the active state
- [x] Tutorial book as a `Button` with the book image; keep `openTutorial()`
- [x] Keep the camera tap animation, Create Roll / Join a Roll buttons and blur-tap close exactly as now
- [x] Close button (top left) in the active state from Figma Toolbar - Top
- [x] `FloatingTabBarView`: drag to move the selection pill, snap to the nearest tab on release, haptic on tab change; tap still works; accessibility unchanged
- [x] Delete the unused assets and components listed above
- [x] Tests (Swift Testing): layout math (uniform scale, vertical centering, a Figma point maps to the same relative spot on 402×874, 375×667, 440×956); tab bar drag math (finger x → tab index, snap, clamping at both ends)
- [x] Build and run all tests on Simulator; compare a Simulator screenshot with the Figma screenshot (Idle and CameraClick)
- [x] Manual check on iPhone 17 and iPhone Air (done by the user, all passed, including the full-page blur fix): nothing cut or misplaced, no fake Dynamic Island, no blur strip behind the tab bar, camera animation as before, close button, tab bar drag

## Out of scope
- New behavior for the other desk objects (toolbox, film rolls, ruler): decoration only
- The tutorial flow itself (stays an open stub)
- Changing the camera animation, Create Roll / Join a Roll look, or the Roll flow
- Explore / Profile screens
- `CameraRollMenuView` and `DeskSurface` (see Open)
- Writing to Figma

## Open
- `CameraRollMenuView` (and its `DeskSurface` asset, 7.4 MB) can no longer be reached: nothing pushes `.cameraRollMenu` since the Workbench popup replaced it. Remove in a later change?

## Notes
- The cutting mat, measurements and shading are vector layers in Figma; they are exported as images (user decision), not drawn in code
- The old `WorkbenchBackgroundActive` PNG already had the camera and buttons printed in; it was never used

## Implementation findings
- Figma exports are cut at the Figma frame edge (402×874): the parts of the toolbox, blue book, ruler, paper balls, stationery 4/5, mat and wood that lie outside the frame are not in the files. Every iPhone shows exactly the frame width and at least the frame height (ratio ≤ 874/402), so those parts are never on screen; the layout test `deskCoversEveryIPhoneScreen` guards this. Getting truly uncut files needs the objects moved inside a larger frame in Figma (not done: no Figma edits)
- Rebuilding objects from the raw Figma source images was tried and dropped: Figma applies fill rotation / image color adjustments that the API does not return (toolbox came out rotated wrong, blue book too light), so the exports are the only exact match
- PNG exports from the Figma API include the frame fill (#9A5531) behind the object, so assets are exported as PDF (transparent, with shadows) and rendered to PNG @1x/@2x/@3x
- Each asset frame = the layer bounds plus its drop shadow, clipped to the Figma frame; positions were checked by matching every export against a 3× render of the Figma frame (all within 1 pt; the blue book and stationery 3 are hidden under the tab bar there, so their frames come from the same bounds rule)
- `DeskWood` is JPEG (opaque photo, 8.5 MB as PNG → 1.4 MB). `Assets.xcassets/Workbench/` is 9 MB in total (old backgrounds were ~10.7 MB plus unused desk assets)
- `DeskDisposableCamera` (catalog root) is the Figma source image of "dispo 1/2", resized; the camera keeps its code rotation and the current animation. Idle position now follows Figma (center 111.7, 375.7; was 112, 450 on the old picture); active center unchanged (155, 335)
- Create Roll / Join a Roll: same look, spacing and center as before, now scaled with the uniform layout
- Close button reuses the existing `BackCircleButton` (same look as the Figma toolbar back button), top left inside the safe area
- Blur: the whole desk is flattened into one layer (`drawingGroup`) and then blurred, so it is one even full-page blur like the Figma CameraClick background blur (user found the first version looked blurred per object on device). `opaque: true` keeps the screen edges from fading to the background color. Radius 12 and the 18% dim are unchanged
- Tab bar: one selection pill now drawn behind the icons (was one per button) so it can follow the finger; selection haptic (`.sensoryFeedback(.selection)`) fires on every tab change, also on tap
- Tests: 85 tests in 10 suites pass (`WorkbenchLayoutTests`, `TabBarDragMathTests` new), 1 known issue (toggle contrast from 003). Visual check: Simulator render of Idle and CameraClick compared with the Figma screenshots
