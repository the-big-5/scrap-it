# 058: Shots-Left Sync Indicator
Status: Done

## Why
After tapping the shutter, the shots-left dial does not decrease until the shot is confirmed and synced to CloudKit. During this network interval, users lack immediate visual and tactile confirmation that the capture is being processed and uploaded. Adding a status indicator around the dial along with a gentle pulsed vibration pattern and a satisfying mechanical decrement latch haptic provides immediate, tactile feedback without altering the authoritative decrement timing.

## Touches
- `flows.md` (F3: Roll)
- `ui.md` (Screen: Camera)
- `tech.md` (Live transport, Camera)

## Changes
- ADDED: Yellow loading ring indicator rendered as a subtle rotating progress arc around the 83×83 outer rim of `ShotsLeftDialView`.
- ADDED: `startContinuousHum()` and `stopContinuousHum()` methods in `HapticService` providing a gentle pulsed vibration pattern with periodic empty gaps during sync.
- ADDED: `playDialDecrement()` method in `HapticService` providing a crisp, multi-transient mechanical ratchet latch click when the remaining shots count decrements.
- MODIFIED: `ShotsLeftDialView` to accept an `isSyncing: Bool` state that activates the rotating yellow ring animation and sync pulse haptic while sync is in progress, and invokes `playDialDecrement()` upon decrement.
- MODIFIED: `RollFlowViewModel` to publish `isSyncingShot` while background CloudKit slot claim tasks are in flight, clearing it once the authoritative slot count arrives.
- MODIFIED: `CaptureSessionView` to pass the sync state from `RollFlowViewModel` into `ShotsLeftDialView`.

## Tasks
- [x] Track in-flight slot claims in `RollFlowViewModel` to expose `isSyncingShot`.
- [x] Implement rotating yellow progress arc around the 83×83 outer dial in `ShotsLeftDialView` driven by `isSyncing`.
- [x] Connect `isSyncing` in `CaptureSessionView` to `ShotsLeftDialView`.
- [x] Ensure dial count holds until CloudKit sync finishes, then decrements with normal odometer animation.
- [x] Write unit tests for sync indicator state transitions in `RollFlowViewModel` and `ShotsLeftDialView`.
- [x] Add pulsed sync haptic start and stop methods in `HapticService` with periodic gaps and reduced intensity.
- [x] Add satisfying mechanical two-stage latch haptic (`playDialDecrement`) in `HapticService` for dial decrements.
- [x] Trigger sync pulse while `isSyncing` is active in `ShotsLeftDialView` and fire `playDialDecrement` when the count decreases.
- [x] Add unit tests verifying sync pulse and dial decrement haptics.

## Out of scope
- Optimistic local decrement prior to CloudKit confirmation.
- Modifying CloudKit retry intervals or conflict handling logic.
- Redesigning shutter button tap haptics or animations.
