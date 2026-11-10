# 020: Upload each shot right after capture, keep uploading after the app closes
Status: Done

## Why
When a roll ends, every phone first uploads all of its shots one by one (2 CloudKit saves each, ~1.5–3 s per shot), then downloads friends' shots one by one (~0.5–1.5 s each), and only checks for friends' shots at 0, 2, 5 and 10 s after its own upload (`RollFlowViewModel.finalizeSessionAndOpenScrapbook`). Estimate for 24 shots / 4 people: ~20–45 s until everything is there, and a friend who needs longer than the 10 s window only shows up after the next app launch. The user wants the photos as fast as possible after End Roll, and accepts uploading during the roll (this reverses part of change 015).

## Touches
flows.md (F3 steps 7, 10 and edge cases), tech.md (upload lifecycle, restore)

## Changes
- MODIFIED (reverses 015's "upload only at the end"): each shot is uploaded in the background right after it is captured, once its slot claim is confirmed (change 016) and its Live Photo movie is saved (one encrypted payload with photo + movie, as in 012). The shutter never waits for it; low priority so capture stays smooth
- Shots that lose the last-shot race (016) are never uploaded, because the upload waits for the confirmed claim
- MODIFIED: uploads keep running when the app goes to the background or is closed: CloudKit long-lived operations (`isLongLived`), which the system finishes without the app. The encrypted payload file is kept in the app's storage (not a temp file) until the save finishes
- On the next launch: running long-lived uploads are picked up again and their shots marked as synced; shots still not uploaded (e.g. the phone was offline) are uploaded again for live **and** ended rolls (015 only retried ended rolls). Same record name (shot ID), so no duplicates
- Abandoned or deleted rolls may now have shots in CloudKit (accepted by the user; 015's quota concern no longer applies)
- Others still cannot see shots during the roll: restore and download only run for ended rolls (tech.md "hidden from others until session ends" unchanged)
- MODIFIED, End Roll: the phone uploads whatever is left (usually 0–1 shots), then keeps fetching friends' shots every few seconds **until the number of local shots equals the roll's shots used**, max 2 minutes (replaces the fixed 10 s window). Anything still missing after that comes with the next launch, as today
- MODIFIED: friends' shots are downloaded several at a time (batch / parallel) instead of one by one
- No UI change

## Tasks
- [x] Upload a shot after its claim is confirmed and its movie is saved (`RollFlowViewModel`), in the background
- [x] `CloudKitSessionService`: long-lived CloudKit saves for `RollShot` and `RollShotRef`; payload file in app storage, deleted after success
- [x] Launch: reattach to running long-lived uploads, mark shots synced on success; retry unsynced shots of live and ended rolls
- [x] End Roll: upload the rest, then sync until local count == shots used or 2 minutes
- [x] `ScrapbookArchiveSync`: download missing shots in batches / parallel
- [x] Tests (Swift Testing): capture uploads after claim (not before); a lost-race shot is never uploaded; End Roll sync stops when the count matches and after the time limit; retry includes live rolls; no duplicate shot on re-upload
- [x] Build and run all tests on Simulator
- [x] Manual check (2+ phones): take photos, End Roll → all photos on every phone within a few seconds; close the app right after a shot → the shot is in CloudKit Console (`RollShot`) without reopening the app — user confirmed on two iPhones after two fixes (background time from the shutter on): photos arrive fast, slot updates and the participant's last photo reaches the host after leaving the app. The envelope count still lags a little (noted as [Open] in tech.md). Force-quit not tried

## Out of scope
- The reveal screen after End Roll (change 021)
- Smaller files, thumbnails or a different payload format
- Pushing "uploaded" signals over Supabase
- Deleting CloudKit shots of abandoned rolls

## Open
- Force-quit: long-lived CloudKit operations run in the system's CloudKit process; whether a swipe-up force-quit stops them needs the manual check. If it does, the launch retry still uploads them
- Offline while capturing: the shot waits on the phone until the app runs with a network again (no upload while closed and offline)

## Implementation findings
- `RollFlowViewModel`: `shotsAwaitingClaim` / `shotsAwaitingMovie` (in memory); `recordCapturedShot(…, expectsLiveMovie:)`; `uploadShotIfReady(_:)` runs inside the background claim task (after `finalizeSessionAndOpenScrapbook` for the last shot, so End Roll never waits) and inside the shutter's movie task. The old "roll ended while the movie was encoding → re-upload" block is replaced by this
- End Roll: `uploadPendingPhotos(for:excluding:)` skips shots still waiting for their claim or movie; then `syncFriendsShotsOnce` every 3 s (`friendsShotsSyncInterval`) while `shouldKeepSyncingFriendsShots(localCount:shotsUsed:elapsed:)` (local shots < shots used, < 120 s). The loop keeps running after the roll screens close (the reveal of change 021 shows photos as they arrive) and stops when the roll is gone from the store
- `CloudKitSessionService`: `uploadShot(_:)` (static `uploadingShotIDs` so two service instances never send a shot at the same time); `RollShot` and `RollShotRef` saved at the same time as two long-lived `CKModifyRecordsOperation`s (`configuration.isLongLived`, `.utility`); payload file in `Application Support/PendingShots/<shot ID>.bin`, deleted when the `RollShot` save succeeds; synced only when both saves succeed; `uploadAll` sends several shots in parallel
- Launch: `MainShellView` runs `resumeShotUploads()` (one line, next to the existing archive restore): reattaches every long-lived operation (`fetchAllLongLivedOperationIDs` / `fetchLongLivedOperation`), marks a shot synced when both parts are saved, sends it again if a part failed, then `syncPendingOfflinePhotos()` for all unsynced shots (live and ended). Back online also calls `syncPendingOfflinePhotos()`
- `RollRoomServicing.downloadShotPayloads(recordNames:)` (default: one by one, so test fakes keep working); `CloudKitRollRoomService` fetches batches of 6 records (`records(for:)`) in parallel. `ScrapbookArchiveSync.restore` uses it
- `enqueueOrUploadPhoto` (already unused before this change) is left in place
- Tests: `RollBatchUploadTests` — shot uploads after its claim; Live shot waits for its movie; lost-race shot is never uploaded; End Roll sync stop rule; same record name / payload file on re-upload; launch retry includes live rolls (replaces 015's two "no upload during the roll / ended rolls only" tests). Full suite: 210 tests in 21 suites pass, 1 known issue (toggle contrast, 003)
- Test-only crashes found and fixed on the way: background End Roll / upload tasks touched SwiftData objects after a test's in-memory store was gone (guards on `session.modelContext`, upload inside the claim task instead of a separate one)
- Local rolls (no `ckRecordName`: no iCloud, Simulator): End Roll marks their shots as done without uploading and runs one archive sync, no 2-minute loop (nothing can arrive from friends). Also keeps background End Roll work from outliving a test's store
- Device check 1 (user): leaving the app right after a photo froze the slot (others saw no change until the app was reopened), and a participant's last photo was missing on the host after End Roll (host 4, participant 5): iOS suspends the app at once, so the slot claim (016), its Supabase broadcast and therefore the upload (which waits for the claim) stopped. Fix: `Core/Services/BackgroundTime.keepAlive` (`beginBackgroundTask`, about 30 s) around the optimistic and confirmed slot broadcasts, the claim task (claim → broadcast → upload start) and the Live Photo movie → upload step. After that the long-lived saves go on without the app. Needs the same device check again
- Device check 2 (user): still no slot change after leaving right away. The background time only started after the photo was processed; leaving during capture / filter / encode froze the shot before it was even recorded. Now `shutterTapped` keeps the whole shot alive from the shutter (capture → record → slot claim → movie → upload start). Needs the device check again

