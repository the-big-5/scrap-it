# 040: Shutter Button Pressed Animation and Haptic
Status: Done

## Why
In `CaptureSessionView`, the metallic circular shutter button currently uses `.buttonStyle(.plain)` without any visual depression or tactile feedback when pressed. Furthermore, when capture is triggered via the iPhone's physical Camera Control button (or volume down on supported hardware), no visual response appears on the screen shutter button, and no analog shutter haptic is emitted.

Adding a mechanical pressed animation (scale and depth compression) and an analog shutter haptic pattern to both screen taps and Camera Control capture triggers creates a tactile, responsive analog camera feel.

## Touches
ui.md (Capture session screen), tech.md (Haptic feedback, Camera capture interaction)

## Changes
- MODIFIED `ScrapIt/Core/Services/HapticService.swift`:
  - Add `playShutterClick()` analog haptic pattern (crisp mechanical transient feedback simulating physical shutter release).
- MODIFIED `ScrapIt/Features/Roll/RollFlowViewModel.swift`:
  - Add published/observable shutter visual trigger state (or trigger event) so Camera Control primary capture activates the button animation.
  - Trigger `HapticService.shared.playShutterClick()` on capture execution.
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Implement pressed animation for metallic circular shutter button (scale down on press with spring release).
  - Connect visual pressed animation to both direct touch press (custom `ButtonStyle` or gesture state) and `RollFlowViewModel` capture trigger from Camera Control.

## Tasks
- [x] Add `playShutterClick()` in `HapticService.swift`
- [x] Expose shutter press animation state/trigger in `RollFlowViewModel.swift`
- [x] Update shutter button in `CaptureSessionView.swift` to render pressed animation for both touch and Camera Control trigger
- [x] Trigger shutter haptic on capture execution
- [x] Add unit test verifying shutter trigger state updates during capture
- [x] Run test suite to verify no regressions

## Out of scope
- Modifying knurled zoom wheel or viewfinder layout
- Changing Camera Control zoom gesture handling
- Altering photo capture pipeline, filters, or CloudKit synchronization
