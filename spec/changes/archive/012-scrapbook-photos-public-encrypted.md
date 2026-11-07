# 012: Scrapbook photos in the public database (encrypted), restore on a new phone
Status: Done

## Why
Roll photos sync to the user's private iCloud through SwiftData (006). That fills the user's iCloud storage ("Quota Exceeded" during 011 testing). The user wants scrapbooks and photos stored in the app's **public CloudKit database** (developer quota) so they survive a new phone, and made **as hard as possible to read through the API** by anyone else.

## Touches
tech.md (Sharing, Data models, CloudKit notes), flows.md (F1 restore after sign-in, F5 scrapbook), ui.md (Scrapbook: Live Photo)

## Changes
### Where data lives
- MODIFIED SwiftData: only `UserProfile` keeps syncing to the user's private iCloud (tiny, needed for sign-in). `CaptureSession`, `Scrapbook`, `ScrapPhoto` move to a **local-only** store (no iCloud sync). Two SwiftData configurations; new rolls only (user decision), existing local test data is not migrated
- MODIFIED tech.md "Sharing: CKShare for sessions and scrapbooks [Locked]" (user decision): the room stays a CKShare (011); scrapbook photos are stored in the public database, encrypted, as below

### Public database: encrypted blobs with random names
- Each shot is uploaded as a public `RollShot` record named with a random UUID (unguessable). It holds **one encrypted payload**: photo, Live Photo movie (if any) and metadata (author, caption, time). No readable fields, no searchable / queryable indexes, so nobody can list or search them
- Encryption: AES-GCM (CryptoKit) with a random 256-bit **roll key** per roll
- The roll key is stored only in the room's `RollSession` record (011), which only roll members can read through the CKShare. Without the key a public record is unreadable noise

### Members-only index (in the room zone, 011)
- For every uploaded shot, the author adds a small `RollShotRef` record (shot record name, author, time) to the room zone. Only members can read it. This replaces any public query: nobody can find shots without being in the roll
- The scrapbook (title, members, date) is rebuilt from the room record; no scrapbook record in the public database

### Restore on a new phone (automatic, user decision)
- After sign-in (and on every launch, in the background), the app lists the user's rooms: own rooms (`Roll-*` zones in the private database) and joined rooms (shared database). No query index needed
- For each finished roll not on the phone yet: read the roll key and the shot refs from the room, download the public `RollShot` records, decrypt, and rebuild the local `Scrapbook` and `ScrapPhoto`s, including Live Photo movies (user decision: restore all)
- Idempotent: shots already on the phone are skipped

### Upload
- MODIFIED `CloudKitSessionService` shot upload: encrypt with the roll key, random record name, Live Photo movie included; then write the `RollShotRef` in the room zone. Offline queue unchanged (uploads when back online)

### Live Photo in the Scrapbook screen (user request at approval)
- Photos with a Live Photo movie show a small "LIVE" badge in the scrapbook grid; long-press plays the Live Photo like the Photos app (`PHLivePhotoView`, from local data, no Photos permission). Badge and gesture [Draft] (the Scrapbook screen design is still [Open])

### Hardening outside the code (CloudKit Console, before Production; documented, not automatable from the app)
- Public `RollShot`: no queryable / searchable / sortable indexes
- Security roles: no "World" read (only signed-in iCloud users can read); creators write their own records

## Tasks
- [x] SwiftData: two configurations (profile synced, local store for `CaptureSession` / `Scrapbook` / `ScrapPhoto`)
- [x] Roll key: create with the room (host), store in `RollSession`; read it when joining / restoring
- [x] `RollShotCrypto` (CryptoKit AES-GCM): seal / open a payload (photo, optional movie, metadata)
- [x] Shot upload: encrypted public `RollShot` (random name, single encrypted asset) + `RollShotRef` in the room zone; offline queue keeps working
- [x] Restore service: list own + shared room zones, fetch key + refs, download, decrypt, rebuild scrapbooks; skip existing; runs after sign-in and on launch
- [x] Scrapbook grid: "LIVE" badge + long-press Live Photo playback (shared Live Photo view, also used by the DEBUG viewer)
- [x] Room deletion still only before the roll starts (Delete roll in the lobby), so finished rolls keep their index
- [x] Tests (Swift Testing, CloudKit behind protocols with fakes):
  - encrypt → decrypt round trip; wrong key fails; payload has no readable text
  - record names are random UUIDs; no metadata fields outside the encrypted payload
  - restore rebuilds scrapbook + photos (+ Live Photo) from fake rooms; second run adds nothing; rolls without a key are skipped
  - profile store still syncs; roll models are local
- [x] Build and run all tests on Simulator
- [x] Manual check: take photos in a roll on phone A, delete the app (or use phone B with the same iCloud), sign in → scrapbook and photos (and Live Photos) come back; a different iCloud that is not in the roll cannot see them — user confirmed on iPhone: all 4 shots appear as public `RollShot` records (2 showed up late, upload still in progress when first checked) and restore on the phone works. Not reported: the "different iCloud cannot see them" check

## Out of scope
- Migrating existing local or private-iCloud test data (new rolls only)
- A "Restore" button or progress UI (restore runs in the background)
- Deleting a scrapbook from the cloud
- Deploying the schema / security roles to Production (manual Console step, before TestFlight)

## Open
- Privacy: encrypted public storage is not the same as CloudKit's members-only sharing; product sign-off on storing friends' photos this way
- Leaving a roll (or the host deleting it) removes access to its index and key, so that user can no longer restore it
- Shared iCloud container for the team is still [Open] (public data is per container)

## Notes
- Public database storage counts against the app's quota (grows with the number of users), not the user's iCloud
- The roll key lives in the room the user already has access to, so no extra iCloud Keychain or extra record is needed for restore

## Implementation findings
- SwiftData: `ScrapIt.storeConfigurations` makes two stores. The profile keeps the default store name (existing sign-ins survive) and syncs; `Rolls` (Scrapbook, ScrapPhoto, CaptureSession) is local. Old roll test data stays behind in the default store, unused (new rolls only)
- Roll key: `RollShotCrypto.newRollKey()` when the host creates the lobby; saved on the local `CaptureSession.rollKey` and in the room's `RollSession` (`rollKey` field); participants get it from the room snapshot when joining
- Upload (`CloudKitSessionService.uploadPhotoRecord`): public `RollShot` named `<shot UUID>` with a single `payload` asset (AES-GCM sealed plist: photo, Live Photo movie, author, caption, time), then `RollShotRef` (`ShotRef-<UUID>`, fields `shotRecordName`, `authorID`) in the room zone. The shot is uploaded again when its Live Photo movie finishes, so the movie is in the payload. Sessions without a room (no iCloud) skip the upload
- Restore (`ScrapbookArchiveSync`): `listRooms()` reads all `Roll-*` zones in the private (own) and shared (joined) databases; ended rooms with a key are restored; existing shot IDs skipped; cover = earliest photo. Runs when the main tab view appears (after sign-in, every launch) and when a roll is finalized (fills in friends' photos that already uploaded; the rest arrive on the next launch)
- Live Photo: `LivePhotoPlayerView` moved from the DEBUG viewer to `Core/DesignSystem/` and used by `ScrapbookPhotoCard` (fill mode, long-press plays). The "LIVE" badge already existed
- Room deletion: unchanged, "Delete roll" exists only in the lobby (before Start)
- Tests: `ScrapItTests/Roll/ScrapbookArchiveTests.swift` (crypto + restore), roll key in `RollRoomTests`, store split in `ModelContainerTests`. Test containers now use unique configuration names: the test host app already owns the "default" store (now profile-only), and reusing that name crashed with "Can't assign an object to a store that does not contain the object's entity"
- Full suite on Simulator: 117 tests in 13 suites pass, 1 known issue (toggle contrast, from 003)
- CloudKit Development creates the new fields / record types (`RollShot.payload`, `RollShotRef`, `RollSession.rollKey`) on first save. Old `RollShot` fields (sessionID, authorName, imageAsset…) remain in the Development schema but are no longer written; remove them in the Console before deploying to Production
- An upload hardening fix (check per-record `modifyRecords` results, log failures, retry unsynced shots on launch) was written during the "only 2 of 4 shots" check, then reverted on the user's request because all shots arrived. Known gap: a shot whose save fails while online is marked synced and not retried
