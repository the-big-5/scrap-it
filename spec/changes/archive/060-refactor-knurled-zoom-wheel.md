# 060: Refactor Knurled Zoom Wheel with Discrete Stepping and Remove Telephoto Lens
Status: Done

## Why
The current camera zoom wheel implementation relies on continuous logarithmic scaling, velocity-gain calculations, and floating-point animation interpolation from `ZoomWheelModel.swift`. This produces janky drag interactions, erratic haptic bursts, and frame drops. Additionally, automatic lens switching to telephoto causes unwanted optical jumps, and complex thresholding/0.6s delay timer logic in `LensSwitchingRule.swift` introduces unnecessary stateful latency.

Referencing the updated discrete stepping architecture in [zoom-control-animation](../../../Documents/academy/challenge-7/zoom-control-animation):
1. Replace the janky continuous velocity model with discrete 0.1× stepping driven by accumulated drag translation.
2. Standardize on the 36 discrete steps from 0.5× to 4.0× (matching `zoom-control-animation`).
3. Maintain natural camera drag direction: dragging left zooms in, dragging right zooms out.
4. Remove all tap-to-step and tap-to-jump gestures from the wheel completely.
5. Enforce silent boundary limits: when resting at the minimum or maximum zoom, dragging against the limit produces zero haptic pulses.
6. Allocate sensor coverage deterministically without threshold logic:
   - 0.5×–0.9× uses the Ultra Wide sensor exclusively.
   - 1.0×–4.0× uses the Main sensor exclusively (digital crop up to 4.0× from the 48MP Main sensor).
   - Stepping across 0.9× and 1.0× immediately switches the physical lens on that exact discrete step.
   - Remove telephoto lens usage completely: exclude `.builtInTripleCamera` from device discovery so the camera uses `.builtInDualWideCamera`.
7. Gut `LensSwitchingRule.swift`: remove the 0.6s lock delay timer and settling work items. The lens lock is applied directly on each discrete step transition with `.restricted(.videoZoomChanged)`.
8. Support devices without Ultra Wide by clamping minimum zoom to 1.0×, and keep the wheel disabled at 1.0× on the front camera.
9. Synchronize the iOS 18 hardware Camera Control slider with the discrete 0.1× steps bidirectionally.

## Touches
ui.md (Capture session), tech.md (Camera, Services)

## Changes
- REMOVED `ScrapIt/Core/Models/ZoomWheelModel.swift`:
  - Eliminate continuous log-zoom math, velocity gain curves, detent point friction buffers, and animatable travel state.
- REMOVED `ScrapIt/Core/Models/LensSwitchingRule.swift`:
  - Eliminate the 0.6s lock delay timer, threshold rules, and debounced settling logic.
- ADDED `ScrapIt/Core/Models/ZoomStop.swift`:
  - Port discrete zoom stops structure from `zoom-control-animation` (0.5× to 4.0×, 36 steps of 0.1×).
  - Milestone stops at 0.5×, 1.0×, 2.0×, 3.0×, 4.0×.
  - Normalized progress ratio calculation and rotation angle mapping (`-60°` at 0.5× to `+60°` at 4.0×).
  - Provide stepping helpers (`nextClamped()`, `previousClamped()`) and index lookup, with dynamic clamping to active device minimum zoom.
- MODIFIED `ScrapIt/Core/Services/CameraEngine.swift`:
  - Remove `.builtInTripleCamera` from back camera discovery types; prioritize `.builtInDualWideCamera`, `.builtInDualCamera`, and `.builtInWideAngleCamera`.
  - Ensure 0.5×–0.9× is serviced by the Ultra Wide sensor and 1.0×–4.0× by the Main sensor without telephoto switching.
  - Remove `LensSwitchingRule` lock delay timer work items (`lensLockWorkItem`, `scheduleLensLock`), setting `.restricted(.videoZoomChanged)` immediately on zoom application.
  - Update `updateCameraControls()` to ensure `AVCaptureSlider` covers the discrete 0.1 steps and prominent values matching device milestones.
  - Maintain bidirectional synchronization between hardware Camera Control and discrete zoom steps.
- MODIFIED `ScrapIt/Core/Services/ZoomCapabilities.swift`:
  - Keep `maxDisplayZoom = 4`.
  - Filter out telephoto switchover presets above 2.0× since telephoto cameras are removed.
- MODIFIED `ScrapIt/Features/Roll/Components/KnurledZoomWheelView.swift`:
  - Rewrite component body using the stationary housing and dynamic rib translation from `zoom-control-animation`.
  - Driven by discrete step transitions (every 6.0 pt of drag translation).
  - Direction: dragging left moves to next step (zooms in); dragging right moves to previous step (zooms out).
  - Remove all tap gesture recognizers and tap-to-jump logic entirely.
  - Trigger `HapticService.playRatchetTick()` on each discrete step transition.
  - Enforce silent boundary behavior: zero haptic feedback when dragging against an already pegged min or max limit.
  - Smoothly synchronize with external zoom changes (Camera Control slider or camera flips).
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Update zoom control container and bindings to interface with the new discrete `KnurledZoomWheelView`.
- MODIFIED `ScrapItTests/Camera/ZoomControlTests.swift`:
  - Remove tests dependent on deleted `ZoomWheelModel`.
  - Add unit test coverage for `ZoomStop` discrete stepping, rotation angle mapping, device limit clamping, and silent boundary conditions.
- REMOVED `ScrapItTests/Camera/LensSwitchingRuleTests.swift`:
  - Remove unit tests for deleted `LensSwitchingRule`.

## Tasks
- [x] Remove `ScrapIt/Core/Models/ZoomWheelModel.swift`
- [x] Remove `ScrapIt/Core/Models/LensSwitchingRule.swift` and `ScrapItTests/Camera/LensSwitchingRuleTests.swift`
- [x] Implement `ScrapIt/Core/Models/ZoomStop.swift` based on `zoom-control-animation`
- [x] Remove `.builtInTripleCamera` discovery and lock-delay timers in `ScrapIt/Core/Services/CameraEngine.swift`
- [x] Update `ScrapIt/Core/Services/ZoomCapabilities.swift`
- [x] Refactor `ScrapIt/Features/Roll/Components/KnurledZoomWheelView.swift` with discrete drag stepping, no tap gesture, and silent endstops
- [x] Update `ScrapIt/Features/Roll/CaptureSessionView.swift`
- [x] Update `ScrapItTests/Camera/ZoomControlTests.swift` and verify all tests pass
- [x] Build and verify on iOS Simulator

## Out of scope
- Pinch-to-zoom gesture on the camera viewfinder
- Custom UI slider widget on the capture screen (wheel remains primary on-screen control)
- Exposure or white balance adjustments on Camera Control
