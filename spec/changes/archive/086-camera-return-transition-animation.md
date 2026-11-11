# 086: Camera Return Transition Animation
Status: Done

## Why
Exiting `CaptureSessionView` via the back button currently triggers an immediate `OrientationLock.resetToPortrait()` alongside `popToRoot()`. This produces an abrupt system orientation rotation animation while jumping back to the home screen.

Returning from the camera to the workbench should feel physical, continuous, and seamless via a multi-step transition:
1. `CaptureSessionView` pure cross-fades into the `DeskDisposableCamera` element scaled up to fill the entire page, matching the camera page's current orientation (0° for upright portrait, +90° for Landscape Left, -90° for Landscape Right) with an opaque matching background.
2. A deliberate hold delay elapses showing the zoomed-in camera against the dark background.
3. The dark background fades out to reveal the portrait homepage workbench underneath.
4. Another hold delay elapses showing the zoomed-in camera resting over the workbench.
5. The camera element smoothly spring-animates down to its idle resting position on the cutting mat (-14° rotation), restoring the floating tab bar.

## Touches
flows.md (F3: Roll), ui.md (Capture session, Workbench), tech.md (Orientation, Navigation)

## Changes
### 1. Two-Step Return Transition Sequence
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Update back button action to initiate the coordinated return transition.
  - Step 1: Fade out camera controls and viewfinder into the zoomed-in disposable camera view oriented according to the active camera orientation.
- MODIFIED `ScrapIt/Features/Home/WorkbenchView.swift` & `WorkbenchViewModel.swift`:
  - Add state supporting the incoming camera return animation.
  - Render the homepage in portrait with the disposable camera element initially full-screen and rotated to match the camera exit orientation.
  - Step 2: Spring-animate the disposable camera element from full-screen into its idle position (`cameraIdleCenter`, `cameraIdleRotation` of -14°, `cameraSize`).
  - Restore floating tab bar visibility upon transition completion.

### 2. Navigation and Orientation Coordination
- MODIFIED `ScrapIt/Features/Roll/RollFlowViewModel.swift` / `ScrapIt/App/Navigation/AppRouter.swift`:
  - Coordinate orientation reset and navigation stack pop so `WorkbenchView` is already prepared in portrait before completing navigation pop.
  - Prevent visible system orientation rotation glitches during return.

## Tasks
- [x] Implement Step 1 cross-fade from `CaptureSessionView` into a full-screen zoomed-in disposable camera matching the camera's orientation (+90°, -90°, or 0°).
- [x] Prepare `WorkbenchView` in portrait with the camera item zoomed in prior to navigation stack pop.
- [x] Implement Step 2 spring animation returning the disposable camera from full-screen zoom to idle position (-14° rotation on the cutting mat).
- [x] Restore floating tab bar visibility when the return animation finishes.
- [x] Add unit tests verifying orientation state, transition flags, and navigation flow on camera exit.
- [x] Run full test suite to ensure no regressions.

## Out of scope
- Forward transition from Homepage to Camera (creation and lobby flows continue to handle roll setup).
- Changes to the camera viewfinder layout or active photo capture controls.
- Landscape support on Homepage or non-camera screens.
