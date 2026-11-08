# 011: Supabase Realtime Photo Slot Count Sync
Status: Done

## Why
During an active capture session, collaborative slot updates currently rely on a 3.0-second CloudKit polling timer (`CloudKitSessionService.startLiveSessionPolling`) that awaits `syncPendingOfflinePhotos()` before fetching `RollSession`, while `RollFlowViewModel.recordCapturedShot` awaits JPEG `CKAsset` uploads directly on the shutter path. This causes multi-second lag where User A can still see `00/24` while User B is already at `12/24`.

To make the shared shot counter update immediately (`<50ms`) with minimal code and without touching the rest of the roll flow, this change introduces **Supabase Realtime Broadcast** (`supabase-swift`) strictly for **photo slot count updates** during the active camera capture session, while unblocking photo uploads from the shutter and polling paths.

## Touches
tech.md (Third-party libraries approval for `supabase-swift`, `.xcodeproj` SPM package exception, hybrid CloudKit + Supabase Realtime slot sync, Code structure `Core/Services/`), flows.md (F3 live shot count sync), `.gitignore` (`SupabaseSecrets.plist`)

## Changes
- APPROVED EXCEPTION (`tech.md`):
  - Approve official `supabase-swift` Swift Package (`https://github.com/supabase/supabase-swift`) and `.xcodeproj` package linkage for target `ScrapIt`.
  - Resolve `[Open]` live transport note in `tech.md`: CloudKit remains durable storage, asset sync, and atomic `.ifServerRecordUnchanged` slot arbiter; Supabase Realtime Broadcast delivers instant `<50ms` shot counter updates during active capture.
- ADDED: Secrets & Configuration (zero hardcoded credentials in git):
  - Add `SupabaseSecrets.plist` to `.gitignore`.
  - Add `ScrapIt/Resources/SupabaseSecretsExample.plist` (tracked template with placeholder `SUPABASE_URL` and `SUPABASE_ANON_KEY`).
  - Add `ScrapIt/Core/Services/SupabaseConfig.swift` (`struct SupabaseConfig`) loading `SUPABASE_URL` and `SUPABASE_ANON_KEY` from bundled `SupabaseSecrets.plist`, returning `nil` when missing or placeholder so local builds and unit tests work without credentials.
- ADDED: `ScrapIt/Core/Services/RollRealtimeService.swift` (PascalCase, no numbers):
  - Define minimal payload `RollSlotBroadcast: Codable, Sendable, Equatable` containing `slotsUsed: Int`.
  - Define `RollSlotRealtimeProviding` protocol (`connect(rollCode:onSlotUpdate:)`, `broadcastSlotCount(_:)`, `disconnect()`) so `RollFlowViewModel` stays unit-testable without live sockets.
  - Implement `SupabaseRollSlotRealtimeService` using official `supabase-swift` Realtime Broadcast on channel `roll:<rollCode>` (event `"slot_taken"`).
  - Implement `NoopRollSlotRealtimeService` fallback when `SupabaseConfig` is unconfigured.
- MODIFIED: `ScrapIt/Features/Roll/RollFlowViewModel.swift` (Camera capture scope only):
  - Inject `any RollSlotRealtimeProviding` (defaulting to `SupabaseRollSlotRealtimeService` when `SupabaseConfig.load()` succeeds, otherwise `NoopRollSlotRealtimeService`).
  - Connect to `roll:<rollCode>` when the camera screen appears (`cameraDidAppear`) and disconnect when leaving the camera (`cameraDidDisappear`) or finalizing the session (`finalizeSessionAndOpenScrapbook`).
  - In `recordCapturedShot`: after `claimSlotAtomically` succeeds and `ScrapPhoto` is saved locally to SwiftData, immediately call `broadcastSlotCount(newSlotsUsed)` and move `cloudService.enqueueOrUploadPhoto` into a non-blocking background `Task`.
  - On receiving a remote `slotsUsed` update: apply `session.slotsUsed = min(max(session.slotsUsed, incomingSlots), session.rollSize)` and, if `session.slotsUsed >= session.rollSize`, finalize the roll (`finalizeSessionAndOpenScrapbook()`).
- MODIFIED: `ScrapIt/Core/Services/CloudKitSessionService.swift`:
  - In `startLiveSessionPolling`, fetch the lightweight `RollSession` CloudKit record first to reconcile `slotsUsed`, and run `syncPendingOfflinePhotos()` in a separate non-blocking `Task` so pending uploads never delay fallback slot checks.
- ADDED: `ScrapItTests/RollRealtimeServiceTests.swift`:
  - Unit tests verifying `SupabaseConfig` missing/placeholder fallback, outgoing `broadcastSlotCount` on capture, idempotent incoming `slotsUsed` updates (`00/24` → `12/24`), auto-finalization when incoming `slotsUsed` hits `rollSize`, and non-blocking `recordCapturedShot` execution.

## Tasks
- [x] **Step 1 — Secrets template & `.gitignore` setup**: Add `SupabaseSecrets.plist` to `.gitignore` and create tracked `ScrapIt/Resources/SupabaseSecretsExample.plist` with placeholder `SUPABASE_URL` and `SUPABASE_ANON_KEY` keys → *verify*: `git check-ignore ScrapIt/Resources/SupabaseSecrets.plist` succeeds while `SupabaseSecretsExample.plist` remains tracked.
- [x] **Step 2 — Safe configuration loader (`SupabaseConfig.swift`)**: Create `ScrapIt/Core/Services/SupabaseConfig.swift` reading valid `URL` and non-empty `anonKey` from `SupabaseSecrets.plist` (returning `nil` if missing or placeholder) → *verify*: unit test confirms `nil` fallback on missing/placeholder plist and valid parse on mock dictionary.
- [x] **Step 3 — Add `supabase-swift` SPM dependency**: Link `https://github.com/supabase/supabase-swift` (`Supabase` product) to target `ScrapIt` in `ScrapIt.xcodeproj` → *verify*: `xcodebuild -resolvePackageDependencies` and target build succeed cleanly.
- [x] **Step 4 — Implement `RollRealtimeService.swift` (slot count only)**: Create `RollSlotBroadcast`, `RollSlotRealtimeProviding`, `NoopRollSlotRealtimeService`, and `SupabaseRollSlotRealtimeService` subscribing/broadcasting `"slot_taken"` on channel `roll:<rollCode>` → *verify*: project compiles cleanly under strict Swift concurrency with zero numbers in filenames/types.
- [x] **Step 5 — Unblock shutter upload & fallback polling**: Move `enqueueOrUploadPhoto` into a non-blocking background `Task` inside `RollFlowViewModel.recordCapturedShot`, and decouple `syncPendingOfflinePhotos()` into its own `Task` inside `CloudKitSessionService.startLiveSessionPolling` → *verify*: `recordCapturedShot` returns immediately without waiting on CloudKit `CKAsset` upload.
- [x] **Step 6 — Wire camera-only slot sync in `RollFlowViewModel`**: Connect on `cameraDidAppear`, disconnect on `cameraDidDisappear` / `finalizeSessionAndOpenScrapbook`, broadcast `newSlotsUsed` after atomic claim, and apply incoming `slotsUsed` updates idempotently (finalizing if `slotsUsed >= rollSize`) → *verify*: lobby, join, start roll, and host handover code paths remain untouched.
- [x] **Step 7 — Write Swift Testing suite (`RollRealtimeServiceTests.swift`)**: Test `SupabaseConfig` fallback, outgoing slot broadcasts, incoming slot jumps (`0/24` → `12/24`), final-slot roll completion, and existing test suites → *verify*: `xcodebuild test` passes 100% on iOS Simulator without `SupabaseSecrets.plist` present.
- [x] **Step 8 — Local `SupabaseSecrets.plist` stub & Simulator build check**: Copy `SupabaseSecretsExample.plist` to gitignored `SupabaseSecrets.plist` (ready for user's Project URL & `anon` key) and verify Simulator launch → *verify*: zero build warnings/errors both with and without credentials populated.

## Out of scope
- Lobby real-time events (`participantJoined`, `rollStarted`), host handover broadcasts, or manual host end broadcasts (strictly photo slot count during active capture only).
- Uploading `ScrapPhoto.livePhotoMovieData` to CloudKit or playing Live Photos in Scrapbook.
- Creating Postgres database tables or Row Level Security (RLS) policies in Supabase.
- Replacing CloudKit or SwiftData for authentication, photo storage, or persistent scrapbooks.
- Live collaborative scrapbooking canvas.
- UI changes to Lobby, Camera, or Scrapbook screens.
