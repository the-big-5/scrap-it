# 007: Camera Control Button Zoom and Animated Knurled Zoom Wheel
Status: Done

## Why
When capturing photos in a shared roll, users need a tactile and responsive camera control experience. The current capture screen uses a static placeholder button that steps through arbitrary zoom factors without animation or tactile feedback, and lacks hardware integration for newer iPhones.

Referencing the camera architecture in [poc-camera](../../../poc-camera) and the physical knurled dial animation in [zoom-control-animation](../../../zoom-control-animation):
1. Support Apple Camera Control button on iOS 18+ devices via `AVCaptureIndexPicker`, allowing physical dial control between lens presets (0.5×, 1×, 2×) and front camera, bidirectionally synchronized with screen controls.
2. Replace the static zoom placeholder in `CaptureSessionView` with a realistic analog knurled zoom wheel featuring horizontal cylindrical rib rolling animation, drag and tap interactions, rigid mechanical hard endstops without rubber-banding, and dynamic `CoreHaptics` tactile feedback.

## Touches
ui.md (Capture session), tech.md (Camera, Services)

## Changes
- ADDED `ScrapIt/Core/Models/ZoomStop.swift`:
  - Discrete zoom stops: `.half` (0.5×), `.standard` (1.0×), `.double` (2.0×).
  - Continuous index mapping, closest stop matching, and clamped step navigation.
  - Interpolated rotation angles for cylindrical rib translation.
- ADDED `ScrapIt/Core/Services/ZoomCapabilities.swift`:
  - Computes device zoom base, presets, and limits using virtual camera switch-over factors and secondary native resolution factors.
  - Translates display zoom (0.5×, 1.0×, 2.0×) to device `videoZoomFactor`.
- ADDED `ScrapIt/Core/Services/HapticService.swift`:
  - `CoreHaptics` (`CHHapticEngine`) service with graceful fallback.
  - Mechanical haptic patterns: ratchet micro-ticks for rib rolling, snap impact when settling into a stop, and heavy mechanical thud when colliding with hard endstops.
- MODIFIED `ScrapIt/Core/Services/CameraController.swift`:
  - Discovers multi-lens back camera devices using `AVCaptureDevice.DiscoverySession` (triple, dual-wide, dual, or wide angle).
  - Implements smooth optical/digital zoom factor application with clamping to device limits.
  - Adds iOS 18+ `AVCaptureIndexPicker` control to `AVCaptureSession` when controls are supported, enabling physical Camera Control button selection synchronized with `zoomFactor`.
  - Synchronizes zoom and camera flip state bidirectionally between hardware Camera Control and the UI.
- ADDED `ScrapIt/Features/Roll/Components/KnurledZoomWheelView.swift`:
  - Fixed 172×44 capsule geometry with stationary metallic gradients, vignettes, and beveled borders.
  - Translating knurled ribs driven by drag or tap gestures.
  - Strict inelastic hard endstops at 0.5× and 2.0× with zero overshoot.
  - Integrated `HapticService` calls for ticks, snaps, and boundary thuds.
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Replaces the static zoom wheel placeholder button with `KnurledZoomWheelView`.
  - Keeps the zoom factor label synchronized with camera and wheel state.
- ADDED `ScrapItTests/Camera/ZoomControlTests.swift`:
  - Unit tests for `ZoomStop` mapping, clamping, and interpolation.
  - Unit tests for `ZoomCapabilities` display zoom calculations and device factor mapping.
  - Unit tests for hard endstops boundary guarantees.

## Tasks
- [x] Create `ScrapIt/Core/Models/ZoomStop.swift`
- [x] Create `ScrapIt/Core/Services/ZoomCapabilities.swift`
- [x] Create `ScrapIt/Core/Services/HapticService.swift`
- [x] Update `ScrapIt/Core/Services/CameraController.swift` with multi-camera discovery, zoom management, and iOS 18 Camera Control picker
- [x] Create `ScrapIt/Features/Roll/Components/KnurledZoomWheelView.swift`
- [x] Update `ScrapIt/Features/Roll/CaptureSessionView.swift` to use `KnurledZoomWheelView`
- [x] Create `ScrapItTests/Camera/ZoomControlTests.swift`
- [x] Build and verify on iOS Simulator
- [x] Run full test suite and confirm all tests pass

## Out of scope
- Continuous analog slider in hardware Camera Control (using index picker for discrete lenses per spec).
- External physical accessories or Bluetooth controllers.
- Changes to .xcodeproj settings or entitlements.
