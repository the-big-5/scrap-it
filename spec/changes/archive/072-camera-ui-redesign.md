# 072: Camera UI Redesign
Status: Done

## Why
Synchronize `CaptureSessionView` and supporting camera components with the updated Figma disposable camera design (`ujlkuWobqxyvtQwh5plhGF`):
- Landscape Reference (Front camera on left): Node `1458:26041`
- Portrait Orientation (Symbols rotated): Node `1531:23441`

Key design refinements:
1. Streamline orientation: Camera body and viewfinder preview remain anchored in reference landscape (front camera on left); device rotation (portrait upright and inverted landscape) adjusts only individual symbols (`flash`, `back navigation`, `flip camera`, `shots-left dial`, `LIVE badge`), eliminating full camera canvas flips. Captured photos retain physical device orientation (upright in portrait).
2. Clean viewfinder HUD: Remove the participant count badge and legacy `DEBUG: LAST SHOT` button. Replace with an interactive `LIVE` badge inside the viewfinder that toggles Live Photo on/off.
3. Dedicated Host End Roll button: Relocate End Roll from inside the viewfinder HUD to a dedicated physical well on the top-right camera deck (host-only, vertical portrait-baseline text).
4. Remove Info button: Remove the circular invite friend / roll code info button on the trailing edge.
5. Simplified zoom switch animation: Remove sliding hatch covers (`ZoomWheelHatchView`). When flipping to front camera, wheel animates back to 1.0x and disables; when flipping back, wheel animates to previous zoom level. Viewfinder mechanical iris remains closed until zoom animation completes.
6. Relocated controls: Flash button moves to left upper well; back button moves to left lower well; flip camera moves to right lower well; analog shots-left dial sits in lower-right deck beside shutter well; legacy bottom control bar removed.

## Touches
flows.md (F2 Capture Flow), ui.md (Screen: Capture session), tech.md (Camera orientation, switching animation)

## Changes
- REMOVED `ScrapIt/Features/Roll/Components/ZoomWheelHatchView.swift`:
  - Delete sliding mechanical dual hatch covers component.
- REMOVED `ScrapIt/Features/Roll/Components/DebugLastShotView.swift` (and debug last shot presentation in `CaptureSessionView.swift`):
  - Deprecate debug last shot viewer.
- MODIFIED `ScrapIt/Core/Models/RollCameraOrientation.swift`:
  - Refactor orientation handling to keep camera body canvas in fixed reference landscape (0° view rotation in landscape right, 90° view rotation when window is portrait).
  - Add symbol rotation calculations for reference landscape (0°), portrait upright (-90°), and inverted landscape (180°).
  - Retain physical photo capture angle calculations so photos are saved upright in portrait.
- MODIFIED `ScrapIt/Core/Services/CameraController.swift`:
  - Store `lastBackCameraZoom: CGFloat` before switching to front camera.
  - Animate zoom factor reset to 1.0x on switch to front camera, and animate restoration of `lastBackCameraZoom` on switch to back camera.
  - Extend switching delay / iris closure so `isSwitchingCamera` remains true until zoom wheel animation finishes, dilating iris open only after wheel settles.
- MODIFIED `ScrapIt/Features/Roll/Components/KnurledZoomWheelView.swift`:
  - Support programmatic animated zoom factor transitions (e.g. rolling ribs smoothly during camera flips).
- MODIFIED `ScrapIt/Features/Roll/Components/ShotsLeftDialView.swift`:
  - Support rotation angle modifier or pivoting element so dial face reorients with symbol rotation.
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Layout update to match Figma node `1458:26041`:
    - Remove top-plate Info button (`CameraInfoRing` + "i").
    - Remove `bottomControlsRow` (flash, live, flip horizontal bar).
    - Left deck: add upper recessed well with Flash button (cycles off/on/auto with `bolt.fill` symbol) and lower recessed well with Back navigation button (`arrow.left` / `chevron.backward`).
    - Top plate: back camera zoom wheel centered at x=594 with "ZOOM 1.0x" text; remove hatch covers.
    - Top-right deck: dedicated "End Roll" recessed button (host only, fixed vertical text).
    - Viewfinder: 444.4 x 337 bezel with 424 x 318 preview (4:3 ratio); remove participant count badge and debug last shot button; add interactive `LIVE` badge button at top-left.
    - Right deck: circular shutter well (154x154) with shutter button, Flip button (`arrow.trianglehead.2.clockwise.rotate.90`) in 72x72 well, and circular analog shots-left dial (83x83).
  - Apply dynamic symbol rotation to: Flash icon, Back button icon, Flip camera icon, Shots-left dial, and LIVE badge.

## Tasks
- [x] Remove `ZoomWheelHatchView.swift` and remove hatch cover integration from `CaptureSessionView.swift`
- [x] Remove `DEBUG: LAST SHOT` button, sheet, and `DebugLastShotView.swift`
- [x] Remove `CameraInfoRing` and Info button from top plate
- [x] Remove legacy `bottomControlsRow` and reorganize Flash, Back, Flip, Shutter, and Shots Dial according to Figma nodes `1458:26041` / `1531:23441`
- [x] Replace participant presence badge with interactive `LIVE` button in viewfinder
- [x] Add dedicated host-only "End Roll" button to top-right camera deck with fixed portrait-baseline text
- [x] Update `RollCameraOrientation` to lock camera body in reference landscape and compute rotation angles for individual symbols
- [x] Apply symbol rotation transforms to Flash, Back, Flip, Shots Dial, and LIVE badge
- [x] Update `CameraController` and `KnurledZoomWheelView` to animate zoom to 1.0x on front switch and restore prior zoom on back switch before iris opens
- [x] Update unit tests for camera orientation, symbol rotation, and zoom transition
- [x] Apply realistic inset and drop shadows to Back, Flash, Flip, and Shutter buttons matching Figma
- [x] Align zoom wheel flush with viewfinder bezel top (y: 33)
- [x] Refine End Roll button to low-profile 36x48 dimensions
- [x] Smooth zoom wheel rolling animations in both front-to-back and back-to-front transitions
- [x] Update Flash OFF state to match dark grey well and thumb position without bolt icon (node 1476:26501)
- [x] Set default flash state to .off
- [x] Flash toggle OFF state includes rotating `bolt.slash.fill` symbol at top
- [x] Flash toggle thumb is rounded square (44x44) with 8pt margin, avoiding edge contact
- [x] Flash toggle alignment consistent between ON (y: 30) and OFF (y: 90), both 8pt from edges
- [x] Lock window interface orientation to portrait (Option A, matching Apple Camera app behavior) eliminating window rotation transitions entirely
- [x] Viewfinder preview orientation fixed by adjusting preview rotation delta for portrait window
- [x] Live indicator button displays diagonal slash across badge when inactive
- [x] Added snap feedback haptics to flash toggle and camera switch buttons
- [x] Shutter press animation depresses only inner silver dome, keeping outer green well stationary
- [x] Ratchet tick haptics emitted during zoom wheel roll when switching between front and back camera
- [x] Prevent camera canvas container from animating rotation; symbols rotate smoothly on device tilt while camera body remains completely stationary
- [x] Fix saved landscape photo orientation for back camera with dynamic island on the left by using direct photoRotationAngle
- [x] Correct front-facing camera preview rotation in portrait orientation so it renders right-side up, recomputing delta on camera switch
- [x] Refine diagonal slash in inactive Live indicator with thinner 1.0pt stroke and rounded line caps
- [x] Rotate zoom text indicator to 180° in landscape orientation with dynamic island on right, and retain previous rotation in portrait
- [x] Add snap feedback haptics to Back button and End Roll button
- [x] Verify build and tests pass

## Out of scope
- Changing AVFoundation capture pipeline, digicam filter shaders, or live photo movie recording
- Modifying CloudKit / Supabase session synchronization or room invite mechanics
- Scrapbook editor, tool tray, or post-capture review flows
- Inverted portrait orientation (upside-down portrait)
