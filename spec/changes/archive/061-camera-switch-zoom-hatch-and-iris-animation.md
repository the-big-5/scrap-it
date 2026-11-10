# 061: Camera Switch Mechanical Iris and Zoom Hatch Animation
Status: Done

## Why
When switching between the back camera and the front camera, `AVCaptureSession` reconfigures inputs on the session queue, halting video buffer delivery for 300 to 500 milliseconds. This causes the Metal preview renderer to stall on the last frame, making the interface appear frozen. Furthermore, the zoom wheel abruptly appears or disappears without visual transition.

This change introduces:
1. An analog mechanical iris diaphragm overlay on the viewfinder that constricts concentric aperture blades to close before the hardware switch and dilates open once the new camera starts delivering frames, masking the reconfiguration latency.
2. A sliding mechanical dual hatch cover over the top-plate zoom wheel slot that slides shut when switching to the front camera and slides open when returning to the back camera.
3. An active switching state and debounce mechanism in `CameraController` to prevent multiple rapid taps while switching cameras.

## Touches
flows.md (F2 Capture Flow), ui.md (Capture session screen)

## Changes
- MODIFIED `ScrapIt/Core/Services/CameraController.swift`:
  - Add published property `isSwitchingCamera: Bool = false`.
  - Update `toggleCameraPosition()` to activate `isSwitchingCamera`, await `engine.switchCamera()`, and deactivate `isSwitchingCamera` once the new device is running.
  - Guard `toggleCameraPosition()` against concurrent calls while `isSwitchingCamera` is true.
- ADDED `ScrapIt/Features/Roll/Components/CameraIrisDiaphragmView.swift`:
  - Component rendering concentric mechanical aperture blades closing inward to black and opening outward with analog mechanical easing.
  - Generates mechanical ratchet haptic feedback during aperture movement.
- ADDED `ScrapIt/Features/Roll/Components/ZoomWheelHatchView.swift`:
  - Dual metallic sliding hatch doors mounted over the zoom wheel recess in the top plate that slide together horizontally to cover the wheel on front camera and slide apart to reveal it on back camera.
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Embed `CameraIrisDiaphragmView` over the viewfinder screen bezel (`screenBezelView`), triggered by `camera.isSwitchingCamera`.
  - Embed `ZoomWheelHatchView` over the zoom wheel section within `topPlateView`, reacting to `camera.isUsingFrontCamera`.
  - Disable the Flip button interaction while `camera.isSwitchingCamera` is true.

## Tasks
- [x] Add `isSwitchingCamera` state and flip debounce to `ScrapIt/Core/Services/CameraController.swift`
- [x] Create `ScrapIt/Features/Roll/Components/CameraIrisDiaphragmView.swift` implementing mechanical aperture blade closure and dilation with haptics
- [x] Create `ScrapIt/Features/Roll/Components/ZoomWheelHatchView.swift` implementing horizontal dual sliding hatch covers
- [x] Integrate `CameraIrisDiaphragmView` over `screenBezelView` in `ScrapIt/Features/Roll/CaptureSessionView.swift`
- [x] Integrate `ZoomWheelHatchView` over the zoom wheel in `topPlateView` in `ScrapIt/Features/Roll/CaptureSessionView.swift`
- [x] Test camera switching in landscape on device/simulator to verify freeze elimination and smooth hatch/iris animations

## Out of scope
- Altering AVFoundation capture pipeline, frame resolutions, or live photo recording logic
- Changing physical camera dimensions, top plate geometry, or bezel frame sizes
- Adding zoom capabilities to the front camera (front camera remains fixed 1.0x)
- Scrapbook editor, album export, or CloudKit synchronization modifications
