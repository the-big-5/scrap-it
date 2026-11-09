# 018: Stop automatic lens switching on close subjects (Pro iPhones)
Status: Done

## Why
On an iPhone 16 Pro (three back cameras) the camera preview "jumps": pointed at a close subject it suddenly looks zoomed in, then not, although the zoom was not changed (user report). The back camera is a virtual multi-lens device (`builtInTripleCamera`, `CameraEngine.camera(at:)`) and iOS is allowed to switch lenses on its own: close focus → ultra-wide (automatic macro), low light → wide instead of tele. Each switch changes the field of view for a moment. Phones with fewer lenses barely show it.

## Touches
tech.md (Camera), flows.md (none), ui.md (none)

## Changes
- MODIFIED: the back camera may switch lenses **only when the zoom changes** (wheel, Camera Control, lens buttons), never because of focus distance or light (automatic macro off). Revised after the first device test (16 Pro still jumped with only `.restricted(.videoZoomChanged)`; user asked to turn macro off): the lens is **locked** (`.locked`) between zooms; each zoom change first allows switching (`.restricted(.videoZoomChanged)`), and 0.6 s after the zoom (and any ramp) settles the lens is locked again. iOS has no public "macro off" switch for apps
- A DEBUG-only active-lens label was used to check this on the 16 Pro (ultra-wide below 1×, wide from 1×, no jump on close subjects) and then removed on the user's request
- Zoom range, lens list and zoom labels unchanged (0.5×–4× where available)
- Front camera and single-lens phones unchanged

## Tasks
- [x] Small pure rule (camera logic, testable): which switching behavior to apply for a device (virtual back camera with switching support → restricted to zoom changes; otherwise nothing)
- [x] `CameraEngine`: apply it when the back camera is configured (inside `lockForConfiguration`), also after switching back from the front camera
- [x] Tests (Swift Testing): rule returns "restricted to zoom changes" for a virtual back camera, nothing for front / single-lens / unsupported
- [x] Build and run all tests on Simulator
- [x] Manual check on an iPhone 16 Pro: point at a close subject (10–20 cm) without zooming → no jump; zoom wheel and Camera Control still move through 0.5× / 1× / 2× / 4×; iPhone 17 / Air unchanged — user confirmed on the iPhone 16 Pro (ultra-wide below 1×, wide from 1×, no jump on close subjects). iPhone 17 / Air not reported separately; Air is unaffected by design (single lens → rule `.unchanged`)

## Out of scope
- A manual macro mode or macro button
- Changing the zoom range, lens buttons or the device priority list
- Low-light tele behavior beyond what the restriction already stops

## Open
- Trade-off: without automatic macro, very close subjects (closer than the wide lens' minimum focus, about 15–20 cm on Pro models) stay blurry instead of switching to ultra-wide. A manual macro option could come later

## Notes
- Simulator has no multi-lens camera, so only the rule is unit tested; the effect needs a Pro iPhone

## Implementation findings
- `Core/Models/LensSwitchingRule.swift`: `resolve(isBackCamera:isVirtualDevice:supportsSwitchingBehavior:)` → `.restrictedToZoomChanges` or `.unchanged`
- `CameraEngine.applyLensSwitchingRule(to:)`: on a virtual back camera that supports it, `setPrimaryConstituentDeviceSwitchingBehavior(.restricted, restrictedSwitchingBehaviorConditions: .videoZoomChanged)` inside `lockForConfiguration`. Called when the session is first configured and when flipping back to the back camera. If the device can't be locked, the default behavior stays
- Tests: `ScrapItTests/Camera/LensSwitchingRuleTests.swift` (4 cases). Full suite: 187 tests in 20 suites pass, 1 known issue (toggle contrast, 003). The two `CameraEngine` concurrency warnings in the build log are older code, not from this change
- Revision (after the first 16 Pro test): `LensSwitchingRule` is now `.lockedBetweenZooms` / `.unchanged` with `lockDelay` 0.6 s. `CameraEngine`: `unlockLensForZoom` (inside the zoom's `lockForConfiguration`, before the new factor), `scheduleLensLock` (debounced on the session queue, waits while a zoom ramp runs, then `.locked`), applied on configure and camera flip. DEBUG: KVO on `activePrimaryConstituent` → `CameraController.debugActiveLens` → yellow label under "ZOOM" in `CaptureSessionView`. 187 tests pass; the device behavior still needs the 16 Pro check
- Debug label removed after the 16 Pro check (user request): no `onActiveLensChanged`, `debugActiveLens` or label left in the code
