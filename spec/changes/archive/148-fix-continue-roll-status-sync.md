# 148: Fix Continue Roll Status Sync Race
Status: Done

## Why
- When the host creates a roll and taps `"Start Roll"` (`startRollCapture()`) before `createInviteLinkIfNeeded` finishes creating the CloudKit room (`createRoom`), `publishSessionToCloudKit` skips updating CloudKit because `session.ckRecordName` is still `nil`. Moments later, `createInviteLinkIfNeeded` finishes with CloudKit's initial `"waiting"` snapshot and calls `apply(snapshot, to: session)`, overwriting the local `.live` status back to `.waiting`.
- Reopening that roll from Workbench → film rolls (`Resume Roll`) then still shows `"Start Roll"` instead of `"Continue Roll"`, and waiting/late-joining participants in CloudKit remain stuck seeing `"waiting"`.
- Even outside that race, `apply(_:to:)` in `RollFlowViewModel` and `WorkbenchViewModel` can revert `.live` / `.ended` status back to `"waiting"` if CloudKit holds a stale snapshot (e.g., offline start or failed `publishSessionToCloudKit`).

## Touches
flows.md (F3: Start Roll & Resume Roll), ui.md (Roll lobby)

## Changes
- MODIFIED `RollFlowViewModel.apply(_:to:)` (`ScrapIt/Features/Roll/RollFlowViewModel.swift`) and `WorkbenchViewModel.apply(_:to:preserveNonEndedForReveal:)` (`ScrapIt/Features/Home/WorkbenchViewModel.swift`):
  - Enforce monotonic status progression (`waiting` → `live` → `ended`) when applying a remote `RoomSnapshot` so a stale `"waiting"` (or `"live"`) snapshot never downgrades a roll that already progressed locally (while preserving existing `preserveNonEndedForReveal` handling on Workbench refresh).
- MODIFIED `RollFlowViewModel.createInviteLinkIfNeeded(currentUser:)` (`ScrapIt/Features/Roll/RollFlowViewModel.swift`):
  - After `roomService.createRoom(draft)` completes and `apply(snapshot, to: session)` sets `ckRecordName`, if `session.status != .waiting` (host already started or ended while room creation was in flight), immediately push `cloudService.publishSessionToCloudKit(session: session)` so CloudKit and participants receive `.live` / `startTime`.
- MODIFIED host resync (`RollFlowViewModel.refreshLobby()`, `RollFlowViewModel.continueRoll()`, and `WorkbenchViewModel.openRoll(_:)`):
  - If the current user is the host of a locally `.live` session whose fetched CloudKit snapshot still reports `.waiting`, re-publish `publishSessionToCloudKit(session: session)` so participants catch up once back online.
- ADDED unit tests in `ScrapItTests/` covering the `Start Roll` vs `createRoom` race, monotonic status application, and host `.live` re-sync on stale `"waiting"` CloudKit snapshots.

## Tasks
- [x] Enforce monotonic `SessionStatus` ordering (`waiting` < `live` < `ended`) in `RollFlowViewModel.apply(_:to:)` and `WorkbenchViewModel.apply(_:to:preserveNonEndedForReveal:)` without breaking `preserveNonEndedForReveal`.
- [x] In `RollFlowViewModel.createInviteLinkIfNeeded(currentUser:)`, publish local `.live`/`.ended` status to CloudKit (`cloudService.publishSessionToCloudKit`) right after `createRoom` succeeds if the host started/ended the roll before room creation finished.
- [x] Re-publish host `.live` status to CloudKit if a fetched CloudKit snapshot still reports `.waiting` during `openRoll`, `refreshLobby`, or `continueRoll`.
- [x] Add unit tests for the race condition and monotonic sync, and verify with `xcodebuild test`.

## Out of scope
- Changing `CameraIntroTransitionOverlay` animation timing or `CreateRollLobbyView` UI / button copy (`"Start Roll"` vs `"Continue Roll"`).
- Allowing rollback from `.live` back to `.waiting` or enabling `Edit Room` after a roll has started.
- Editing main `spec/*.md` files before `/merge-change`.
