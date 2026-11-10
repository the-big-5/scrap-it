# 055: Shots Left Dial Odometer Scroll
Status: Done

## Why
When the remaining shots count changes in `ShotsLeftDialView`, the number currently cross-fades rather than animating like an authentic analogue counter drum. To match the physical aesthetic of mechanical camera frame counters and odometers, digits must scroll vertically upward when remaining shots decrement, using independent tumbler wheels per digit with a mechanical curve and a light settling haptic.

## Touches
ui.md (Screen: Camera capture session)

## Changes
- MODIFIED `ScrapIt/Features/Roll/Components/ShotsLeftDialView.swift`:
  - Replace the cross-fading label stack with independent odometer tumbler columns (tens and ones).
  - Animate digits scrolling vertically upward on decrement (old digit moves up, new digit enters from below).
  - Only animate digits that actually change (e.g. tens digit remains stationary when going from 23 to 22).
  - Apply a 0.25s mechanical ease transition clipped strictly within the inner dial drum.
  - Fire a light impact haptic tick (`UIImpactFeedbackGenerator(style: .light)`) when the counter settles.

## Tasks
- [x] Refactor `ShotsLeftDialView.swift` to render tens and ones digits in independent vertical tumbler wheels.
- [x] Implement upward vertical translation animation on decrement with a 0.25s mechanical ease curve.
- [x] Trigger light impact haptic feedback on digit settling.
- [x] Ensure smooth clipping within the inner drum aperture (`CameraDialInner`).
- [x] Verify SwiftUI preview and verify test suite passes without regressions.

## Out of scope
- Modifying `RollFlowViewModel.shotsRemaining` calculation or roll session state.
- Modifying outer dial SVG assets (`CameraDialOuter`, `CameraDialInner`) or layout frame dimensions.
- Changing shutter button animation, haptics, or capture session controls.
