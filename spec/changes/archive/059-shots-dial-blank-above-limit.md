# 059: Shots Dial Blank Above Limit
Status: Done

## Why
When viewing the analog shots dial at full roll capacity (e.g. 36 shots), displaying numbers above the maximum shot limit (such as 37 or overflow tumbler values) is unexpected. The dial slot above the active digit tumblers should be blank when at the roll capacity limit. At the lower boundary (0 shots remaining), the counter should display "00" (zero for each digit).

## Touches
ui.md (Screen: Camera capture session)

## Changes
- MODIFIED `ScrapIt/Features/Roll/Components/ShotsLeftDialView.swift`:
  - Accept `totalShots: Int` alongside `shotsRemaining: Int` so the dial knows the roll capacity.
  - In separate tumbler digit wheels, blank the slot above the active digit when at or above capacity, and align adjacent vertical slots to the physical cylinder sequence (tens wheel displays blank above max tens and preceding digit below, e.g. 1 below 2).
  - When `shotsRemaining <= 0`, keep showing zero for each digit.
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Pass `totalShots` (`flowViewModel.activeSession?.rollSize ?? 36`) to `ShotsLeftDialView`.
- MODIFIED `ScrapItTests/Camera/CameraBehaviorTests.swift`:
  - Add unit tests verifying `ShotsLeftDialView` blanks upper overflow slots at maximum capacity and displays zero at 0 shots.

## Tasks
- [x] Update `ShotsLeftDialView` to accept `totalShots: Int` (defaulting to 36).
- [x] Update tumbler rendering to blank slots above the limit when at roll capacity.
- [x] Ensure zero remaining shots displays zero for each digit.
- [x] Pass `totalShots` from `CaptureSessionView`.
- [x] Add and verify unit tests in `CameraBehaviorTests.swift`.

## Out of scope
- Modifying roll selection or film sprocket strip components.
- Modifying dial SVG assets (`CameraDialOuter`, `CameraDialInner`) or layout frame dimensions.
- Changing shutter button animation, haptics, or roll session state logic.
