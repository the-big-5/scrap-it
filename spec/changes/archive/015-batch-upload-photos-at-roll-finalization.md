# 015: Batch Upload Photos at Roll Finalization
Status: Done

## Why
Currently, every shutter tap in `RollFlowViewModel` immediately triggers `enqueueOrUploadPhoto` in the background, and triggers it a second time when the Live Photo movie finishes encoding. In addition, the 3-second live polling loop repeatedly attempts to sync offline photos while shooting. This causes incomplete, test, or abandoned rolls to upload to CloudKit, wasting developer quota and device bandwidth, while tying the camera shutter to network activity.

By moving photo uploads strictly to the Roll Finalization lifecycle ("Develop at End"), photos remain 100% local on-device in SwiftData while shooting, and are batch-uploaded to CloudKit only when the roll actually finishes (either when all slots are filled or when the host ends the roll early).

## Touches
tech.md (Media, CloudKit upload lifecycle), flows.md (F3: Roll)

## Changes
### 1. Decouple Shutter from CloudKit Uploads
- MODIFIED `RollFlowViewModel.recordCapturedShot`:
  - Remove background `cloudService.enqueueOrUploadPhoto(...)` invocation.
  - Shutter tap strictly performs local SwiftData insertion and Supabase Realtime slot broadcast.
- MODIFIED `RollFlowViewModel.shutterTapped`:
  - When Live Photo movie completes, save `livePhotoMovieData` locally to `ScrapPhoto`; remove the second `enqueueOrUploadPhoto` call.
- MODIFIED `CloudKitSessionService.startLiveSessionPolling`:
  - Remove `await self?.syncPendingOfflinePhotos()` from the 3-second polling timer so polling only queries remote session status.

### 2. Dedicated Roll Batch Upload Method
- ADDED `CloudKitSessionService.uploadPendingPhotos(for session: CaptureSession) async`:
  - Queries local `ScrapPhoto`s for `session.id` where `!photo.isSyncedToCloud`.
  - Encrypts each shot with the roll's AES-GCM `rollKey` and saves `RollShot` to the Public Database and `RollShotRef` to the room zone.
  - Marks `photo.isSyncedToCloud = true` upon success and saves `ModelContext`.

### 3. Wire Upload Trigger to Roll Finalization
- MODIFIED `RollFlowViewModel.finalizeSessionAndOpenScrapbook`:
  - When a roll ends (either naturally at `slotsUsed >= rollSize` or via `endSessionManuallyByHost`), invoke `await cloudService.uploadPendingPhotos(for: session)`.
  - Concurrently trigger `syncScrapbookArchive()` to pull down collaborator shots and decrypt into the scrapbook.

### 4. Background Sync Guard
- MODIFIED `CloudKitSessionService.syncPendingOfflinePhotos`:
  - Guard offline sync on app launch / reconnect so it only uploads photos belonging to sessions where `session.status == .ended`. Active or abandoned rolls remain strictly local.

## Tasks
- [x] Add `uploadPendingPhotos(for session: CaptureSession) async` in `CloudKitSessionService`
- [x] Update `CloudKitSessionService.syncPendingOfflinePhotos` to only process photos from ended sessions
- [x] Remove `syncPendingOfflinePhotos` from `startLiveSessionPolling` timer loop in `CloudKitSessionService`
- [x] Remove `enqueueOrUploadPhoto` calls from `shutterTapped` and `recordCapturedShot` in `RollFlowViewModel`
- [x] Call `uploadPendingPhotos(for: session)` in `RollFlowViewModel.finalizeSessionAndOpenScrapbook`
- [x] Add unit tests:
  - Verify capturing shots during a live roll does not upload to CloudKit
  - Verify finalizing a full roll triggers batch upload of its photos
  - Verify manual early host end triggers batch upload of its photos
  - Verify launch sync ignores photos from in-progress / unended sessions
- [x] Run full test suite to ensure zero regressions across existing tests

## Out of scope
- Changing the AES-GCM encryption format (`RollShotCrypto`)
- Changing Supabase Realtime broadcast (<50ms slot sync)
- Modifying Scrapbook Editor UI or features
