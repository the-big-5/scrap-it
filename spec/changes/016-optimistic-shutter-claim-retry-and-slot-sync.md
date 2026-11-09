# 016: Optimistic Shutter, CloudKit Claim Retry, and Authoritative Slot Sync
Status: Done

## Why
Currently, when a user taps the shutter in `RollFlowViewModel`, the call to `recordCapturedShot` awaits `cloudService.claimSlotAtomically` before returning. This causes:
1. **Perceptible Shutter Delay**: The shutter waits for two sequential CloudKit network operations (reading the room record and saving via `CKModifyRecordsOperation`) at default priority. Supabase Realtime is only broadcast *after* this round-trip completes (0.6–2.0s delay).
2. **Undetected Collision & Overcounting**: If two phones press the shutter simultaneously, CloudKit rejects one save with `.serverRecordChanged`. The current implementation detects this conflict but fails to retry the save; it falls through to incrementing the local slot counter anyway without saving to CloudKit. This leaves the server's count behind, allowing users to keep taking shots past the limit (e.g. >24 photos).
3. **Drift in Supabase Broadcasts**: Supabase broadcasts the local counter rather than an authoritative server counter, amplifying any desync across all peers.

## Touches
- `flows.md` (F3: Roll)
- `tech.md` (Live transport, atomic slot claim, last-shot race)
- `RollFlowViewModel.swift`
- `CloudKitSessionService.swift`
- `RollRealtimeService.swift`

## Changes

### 1. Optimistic Shutter Flow (`RollFlowViewModel`)
- Capture photo and save to `ModelContext` immediately on shutter tap.
- Optimistically increment local `session.slotsUsed += 1` and update camera UI immediately without waiting for CloudKit network response.
- Immediately broadcast the optimistic count via `realtimeService.broadcastSlotCount(optimisticCount)`.
- Initiate background task with `.userInitiated` priority to claim the slot authoritatively via CloudKit.

### 2. Robust CloudKit Atomic Slot Claim with Retry Loop (`CloudKitSessionService`)
- Configure `CKModifyRecordsOperation` with `.qualityOfService = .userInitiated`.
- Implement an atomic retry loop (up to 3–5 attempts):
  - If a collision occurs (`.serverRecordChanged`), immediately re-fetch the latest server record.
  - If latest server slots are still below `rollSize`, re-attempt the save with `serverRecord["slotsUsed"] = latestUsed + 1`.
  - If server indicates roll is full (`latestUsed >= rollSize`), terminate retries and return `.rollAlreadyFinished`.
- Return the authoritative server slot count upon successful save.

### 3. Authoritative Reconciliation and Last-Shot Rejection Handling
- When the background claim succeeds:
  - Update local `session.slotsUsed` to the authoritative server count.
  - Broadcast the authoritative count via Supabase Realtime so all connected peers converge on the exact server number.
  - If the authoritative count reaches `session.rollSize`, mark `session.status = .ended` and finalize session.
- When the background claim fails with `.rollAlreadyFinished` (lost the last-shot race):
  - Revert the optimistic count (`session.slotsUsed = session.rollSize`).
  - Delete the locally captured `ScrapPhoto` from `ModelContext` (per spec F3: "first write wins; the other photo is dropped and that user is told the roll finished").
  - Trigger `showLastSlotRaceAlert = true`.
  - Mark `session.status = .ended` and call `finalizeSessionAndOpenScrapbook()`.

### 4. Offline / Network Interruption Policy
- If offline mid-roll (`!isOnline`), preserve local shot in `ModelContext` with `isSyncedToCloud = false`.
- Do not drop photos when offline; sync will reconcile when reconnected or at roll finalization.

## Tasks
- [x] Refactor `CloudKitSessionService.claimSlotAtomically` to use `.userInitiated` QoS and a retry loop for `.serverRecordChanged`.
- [x] Update `RollFlowViewModel.recordCapturedShot` to decouple the shutter trigger from CloudKit latency (optimistic UI update + instant Supabase broadcast).
- [x] Add background authoritative claim resolution in `RollFlowViewModel`:
  - Authoritative count sync & broadcast.
  - Rejection / rollback handler (delete unclaimable photo, show last-slot alert, end session).
- [x] Add unit tests in `OptimisticShutterSlotClaimTests`:
  - Verify shutter returns immediately without awaiting CloudKit network.
  - Verify collision retry successfully claims slot after initial `.serverRecordChanged`.
  - Verify last-slot race drops rejected photo and triggers alert when roll is full.
  - Verify authoritative count converges and broadcasts correctly via Supabase.
- [x] Run full test suite to guarantee zero regressions.

## Out of scope
- Changing Supabase Realtime transport architecture or schemas.
- Modifying photo encryption or CloudKit zone architecture from Changes 011/012/015.
- Editing scrapbooks or UI layout outside the capture session flow.
