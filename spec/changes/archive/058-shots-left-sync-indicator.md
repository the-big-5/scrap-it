# 058: Shots-Left Sync Indicator
Status: Done

## Why
After tapping the shutter, the shots-left dial does not decrease until the shot is confirmed and synced to CloudKit. During this network interval, users lack immediate visual confirmation that the capture is being processed. Adding a status indicator around the dial shows that synchronization is actively ongoing without altering the authoritative decrement timing.

## Touches
- `flows.md` (F3: Roll)
- `ui.md` (Screen: Camera)
- `tech.md` (Live transport)

## Changes
- ADDED: Yellow loading ring indicator rendered as a subtle rotating progress arc around the 83×83 outer rim of `ShotsLeftDialView`.
- MODIFIED: `ShotsLeftDialView` to accept an `isSyncing: Bool` state that activates the rotating yellow ring animation while sync is in progress.
- MODIFIED: `RollFlowViewModel` to publish `isSyncingShot` while background CloudKit slot claim tasks are in flight, clearing it once the authoritative slot count arrives.
- MODIFIED: `CaptureSessionView` to pass the sync state from `RollFlowViewModel` into `ShotsLeftDialView`.

## Tasks
- [x] Track in-flight slot claims in `RollFlowViewModel` to expose `isSyncingShot`.
- [x] Implement rotating yellow progress arc around the 83×83 outer dial in `ShotsLeftDialView` driven by `isSyncing`.
- [x] Connect `isSyncing` in `CaptureSessionView` to `ShotsLeftDialView`.
- [x] Ensure dial count holds until CloudKit sync finishes, then decrements with normal odometer animation.
- [x] Write unit tests for sync indicator state transitions in `RollFlowViewModel` and `ShotsLeftDialView`.

## Out of scope
- Optimistic local decrement prior to CloudKit confirmation.
- Modifying CloudKit retry intervals or conflict handling logic.
- Redesigning shutter button tap haptics or animations.
