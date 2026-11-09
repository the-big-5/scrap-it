# 037: Roll Camera Dual Landscape Rotation Support
Status: Done

## Why
When iOS Portrait Orientation Lock is enabled on a device, the system locks the window to portrait. `CaptureSessionView` adapts by checking `isPortrait` and applying a static `.rotationEffect(.degrees(90))`.
Because the rotation angle is hardcoded to +90°, the camera layout only displays upright for one landscape orientation. When the user holds the device in the opposite landscape orientation, the entire camera UI, controls, and viewfinder appear upside down.

By tracking physical device orientation when the interface is in portrait, `CaptureSessionView` dynamically rotates the camera interface to +90° or -90° (270°). This matches native behavior: the top camera deck remains at the top and the shutter button and grip remain on the right hand side in both landscape orientations. Camera preview and photo capture rotation also stay aligned so captured photos are saved right-side up in both landscape orientations.

## Touches
ui.md (Capture session), tech.md (Camera, orientation)

## Changes
### 1. Dynamic Device Orientation Tracking in Roll Camera
- ADDED `ScrapIt/Core/Services/CameraMotionService.swift`:
  - Monitors hardware gravity vector via CoreMotion (`deviceMotion.gravity` and accelerometer fallback) so landscape rotations are detected reliably even when iOS system Portrait Orientation Lock is active in Control Center.
  - Keeps `UIDevice.orientationDidChangeNotification` fallback for Simulator and unlocked orientation.
- ADDED `ScrapIt/Core/Models/RollCameraOrientation.swift`:
  - Resolves hardware acceleration and device orientation into `.left` and `.right` landscape sides with deadband and hysteresis.
  - Computes view rotation degrees and camera rotation deltas for portrait window mode while preserving 0° native behavior when unlocked.
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Starts and stops `CameraMotionService` on view lifecycle.
  - Dynamically rotates camera interface between +90° and -90° in portrait mode with smooth animation.
  - Follows native 0° window rotation without manual transforms when orientation lock is off.

### 2. Camera Preview and Photo Capture Rotation Alignment
- MODIFIED `ScrapIt/Core/Services/CameraEngine.swift` (and/or `CameraController.swift`):
  - Support updating video and photo capture rotation based on physical device orientation when interface orientation is locked to portrait.
  - Ensure preview and captured photos remain upright 4:3 landscape shots in both Landscape Left and Landscape Right.

## Tasks
- [x] Add device orientation monitoring to `CaptureSessionView` to detect `landscapeLeft` and `landscapeRight`.
- [x] Update `CaptureSessionView` rotation logic when `isPortrait` is true to apply +90° or -90° rotation with smooth transition animation.
- [x] Align `CameraEngine` / `CameraController` capture and preview rotation with physical device orientation when the window is in portrait.
- [x] Add unit tests verifying orientation angle calculations and transitions for both landscape orientations.
- [x] Run test suite to verify no regressions.

## Out of scope
- Portrait camera body layout (the camera UI remains landscape).
- Orientation changes on non-camera screens (all other screens remain portrait-only).
- Motion/accelerometer tracking outside the Capture session screen.
