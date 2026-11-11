# 100: Camera Horizontal 3D Flip Return Transition
Status: Done

## Why
When exiting `CaptureSessionView` back to the homepage workbench, the current return transition (change 086) cross-fades into a full-screen zoomed-in camera element against an opaque dark background.

Replacing the cross-fade with a physical 3D horizontal flip provides analog skeuomorphic realism:
1. Tapping the back button closes the mechanical iris diaphragm over the live viewfinder.
2. The full-bleed camera view smoothly resizes down to a centered floating camera card over the dark background.
3. The camera performs a 3D horizontal flip around its local Y-axis (matching exit orientation: 0° portrait, +90° landscape left, -90° landscape right), flipping from the camera's back deck to the front face of `DeskDisposableCamera`.
4. The flip runs against the opaque dark background (`Color(red: 42/255, green: 36/255, blue: 31/255)`).
5. After the flip completes, the dark background fades out to reveal the portrait homepage workbench underneath.
6. The front disposable camera element spring-animates from floating zoom down to its idle resting position on the cutting mat (-14.77°), restoring the tab bar.

## Touches
flows.md (F3: Roll capture session exit), ui.md (Camera return transition), tech.md (Navigation & CameraReturnTransitionOverlay)

## Changes
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Trigger mechanical iris diaphragm closure upon tapping the back button before or during the exit flip.
  - Coordinate back action timing with the return transition sequence.
- MODIFIED `ScrapIt/Features/Home/CameraReturnTransitionOverlay.swift`:
  - Animate resize from full-bleed cover down to a centered floating camera card upon entering the overlay.
  - Implement 3D Y-axis horizontal flip (`rotation3DEffect`) oriented along the camera's local Y-axis based on `router.cameraReturnAngle`.
  - Flip from the camera back representation to the front `DeskDisposableCamera` element.
  - Maintain the dark opaque background during the resize and flip, followed by the background fade-out and cutting mat spring animation.
- MODIFIED `ScrapIt/Features/Home/WorkbenchLayout.swift`:
  - Add `fullBleedCameraScale` and `floatingCameraScale` defining scale progressions for portrait and landscape orientations.
- MODIFIED `ScrapItTests/Home/WorkbenchLayoutTests.swift`:
  - Add unit tests verifying transition phases, scale progressions (`fullBleed > floating > 1.0`), and orientation angles for the 3D flip return flow.

## Tasks
- [x] Update `CaptureSessionView` to close the mechanical iris diaphragm on back navigation
- [x] Implement 3D Y-axis horizontal flip in `CameraReturnTransitionOverlay` respecting local camera orientation
- [x] Retain opaque dark background during flip, followed by workbench reveal and spring animation to idle position
- [x] Add unit tests for return transition phase flow and orientation handling
- [x] Run test suite to verify no regressions

## Out of scope
- Forward transition from Homepage into Camera.
- Changes to viewfinder capture HUD, knurled zoom wheel, or photo shutter behavior.
- Modifying idle camera mat coordinates or tab bar implementation.
