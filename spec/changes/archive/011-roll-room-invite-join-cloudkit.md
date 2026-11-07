# 011: Roll room with CloudKit sharing — lobby, invite, share link, join, remove, leave, delete
Status: Done

## Why
The lobby, invite and join screens have new Figma designs, and the room needs real multi-device joining. Today the room (`RollSession`) is a public-database record that joiners try to edit (by default only the creator can edit public records), the `CKShare` is created but never saved (so there is no share link), the invite sheet has a QR code that is no longer in the design, and the lobby updates by polling every 3 s.

This change moves the room to CloudKit sharing (`CKShare`), so an iCloud link opens the app and joins directly (AirDrop and chat apps), a 6-character roll code still works, and host / participant actions (remove, leave, delete) map to share operations. Stays on CloudKit (no WebSocket, tech.md "Live transport: CloudKit only" [Locked]).

## Touches
flows.md (F2, F3 steps 4–5), ui.md (Create Roll Lobby, Invite Friend Sheet, Join a Roll), tech.md (CloudKit room storage, `.xcodeproj` exceptions)

## Figma source
File `ujlkuWobqxyvtQwh5plhGF`

| Frame | Node |
| :--- | :--- |
| Lobby, host | 1011:5883 |
| Invite friend sheet | 1068:4233 |
| Share sheet (system) | 768:1623 |
| Join Roll | 725:6659 |
| Lobby, participant | 768:1291 |
| Host long-press avatar → Remove | 1011:6043 |
| Participant "⋯" → Leave roll | 1129:8947 |

## Changes
### CloudKit room storage
- MODIFIED room storage: the host saves the room in their **private database**, in a custom zone per roll, with the `RollSession` record as the root of a **`CKShare`** (`publicPermission = .readWrite`: anyone with the link can join). The share URL (`https://www.icloud.com/share/…`) is the invite link
- ADDED roll code lookup: a small public-database record per roll (`RollCode-<code>`: code → share URL, roll name). Joining by code fetches it and accepts the same share
- ADDED participants: each person who joins creates their own `RollParticipant` record (id, name) in the shared zone, so nobody edits someone else's record. The lobby lists the participant records
- MODIFIED capture slots: `claimSlotAtomically` and the live session read/write the `RollSession` in the right database (host: private, participants: shared) instead of the public database. Behavior in F3 unchanged (last-shot race, host handover)
- ADDED live updates: CloudKit database subscriptions (private + shared) push changes (join, leave, remove, start, delete) to the lobby; polling stays as a fallback when push is not available
- ADDED accepting a share: opening an iCloud share link (tap, AirDrop) opens the app and joins the roll (`CKSharingSupported`, scene delegate `userDidAcceptCloudKitShareWith`), then shows the participant lobby

### `.xcodeproj` (user approved for this change)
- `INFOPLIST_KEY_CKSharingSupported = YES`: without it iOS does not hand iCloud share links to the app, so the invite link could not open ScrapIt
- `UIBackgroundModes = remote-notification`: CloudKit pushes room changes (someone joins, host starts / deletes, participant removed) as silent notifications; without it the lobby can only poll. Also fixes the "BUG IN CLIENT OF CLOUDKIT … remote-notification" log from 006

### Lobby (host 1011:5883, participant 768:1291)
- Top left X (host and participant): closes the lobby and returns to the Workbench. The roll keeps existing; how to reopen it later is [Open]
- Title = roll name, "N joined" and "N shots", avatar grid with name and "(Host)" / "(You)"
- Avatars: initials in a circle (no profile photos yet; Sign in with Apple gives none). Photos come with the Profile screen [Open]
- Host: top right "add person" button opens the Invite friend sheet; "Delete roll" (text button) and "Start Roll" at the bottom
- Host: long-press on another participant's avatar → "Remove" (1011:6043). Not on the host's own avatar
- Participant: top right "⋯" → "Leave roll" (1129:8947); bottom text "Waiting for the host to start..."; no invite / share
- No confirmation dialogs for Delete / Remove / Leave (user decision; may come later from the PRD)
- Delete roll (host): deletes the room and its share and the roll code record; host returns to the Workbench
- Remove (host): removes the person from the share and deletes their participant record
- Leave roll (participant): leaves the share and deletes their own participant record; returns to the Workbench
- A participant who is removed, or whose roll is deleted, returns to the Workbench with a short message [Draft]: "The host removed you from the roll" / "This roll was deleted"

### Invite friend sheet (1068:4233)
- Sheet with X (close), title "Invite friend", share button (top right)
- "Roll code:" with the 6 characters in boxes, "Copy link" (copies the iCloud share link)
- REMOVED QR code (also from F2: no QR scanning)

### Share (768:1623, system share sheet)
- Host only. Uses `UIActivityViewController` with a `UIActivityItemSource` so the content depends on where it is shared:
  - AirDrop: the iCloud link only (opens the app and joins on the receiving iPhone)
  - Messages, WhatsApp and other messaging apps: text only (no image) [Draft]:
    "Join my roll "<roll name>" on ScrapIt! 📸\nRoll code: <code>\n<link>"
  - Only AirDrop and messaging apps (user decision at approval): Mail and the other built-in non-messaging destinations (Print, Copy, Save to Files / Photos, Reading List, Books, Markup, Assign to Contact, Reminders, Notes, Freeform) are excluded. iOS cannot whitelist apps, so a third-party non-messaging app may still appear; it gets the same text
  - Share sheet preview (`LPLinkMetadata`): title only, no image
- App name "ScrapIt" comes from one constant (the name may change)
- Note: some chat apps (e.g. WhatsApp) build their own link preview from the URL; the app only sends text

### Join Roll (725:6659)
- Opened from Workbench → camera → "Join a Roll"
- Back "<", title "Join Roll", "Enter code" with 6 boxes, "Join" button
- Join: looks up the code, accepts the share, adds the participant record, opens the participant lobby. Late joining allowed while the roll lasts (F2)
- Error messages [Draft]: "No roll found for this code", "This roll has ended", "You're offline. Connect to the internet to join."
- Same iCloud (user request after device testing): when the person opening the link or entering the code uses the same iCloud as the host (same or another device), they go straight into the room as the host: no error, no extra participant. Someone already in the room who joins again is not added twice

## Tasks
- [x] Read exact layout, sizes, colors and fonts from Figma (`get_design_context`, read-only) for the 7 frames; reuse existing components (`BackCircleButton`, DS buttons/tokens) where they match
- [x] `.xcodeproj`: `INFOPLIST_KEY_CKSharingSupported = YES`, `UIBackgroundModes = remote-notification` (nothing else)
- [x] CloudKit room service: create zone + `RollSession` + `CKShare`, roll code record, accept share, participant records, remove / leave / delete, subscriptions; the capture slot code uses the right database
- [x] Scene delegate hook for accepting shares (link tap / AirDrop) → participant lobby
- [x] `RollFlowViewModel` (or a lobby part of it): host / participant state, actions, removed / deleted handling, error messages
- [x] Lobby view (host + participant variants, initials avatars, long-press Remove, ⋯ Leave roll, Delete roll, Start Roll, waiting text, X close)
- [x] Invite friend sheet (no QR), Copy link, share button
- [x] Share sheet wrapper with `UIActivityItemSource` (AirDrop = link, messaging apps = text + link, metadata without image) and excluded non-messaging activity types
- [x] Join Roll screen and flow from the Workbench
- [x] Tests (Swift Testing, CloudKit behind a protocol with a fake):
  - share content per activity type (AirDrop link only; messaging apps text with roll name, code, link; no image); Mail and other non-messaging types excluded
  - host vs participant actions shown; host cannot remove themselves
  - join by code: found / not found / ended / offline
  - remove, leave, delete update the lobby and send the affected user back with the right message
  - initials from names
- [x] Build and run all tests on Simulator
- [x] Manual check on two iPhones signed in to different iCloud accounts, both running the same build (same iCloud container): create, invite by AirDrop and by WhatsApp text, join by code, remove, leave, delete, start — user confirmed on device: invite link created and shared, opening the link with the same iCloud enters the room as host; merged on the user's go-ahead (the other items were not reported one by one)

## Out of scope
- WebSocket or any non-CloudKit live transport
- Reopening a roll after closing the lobby with X [Open]
- Profile photos (initials only)
- Confirmation dialogs
- Changes to the capture screen UI, the scrapbook, the Workbench
- Sharing by participants (host only for now)
- Deploying the CloudKit schema to Production

## Open
- Where the user reopens an existing roll (lobby) after closing it
- Profile photos on avatars
- App name (ScrapIt for now)

## Notes
- Two-device testing needs both phones on a build signed with the same team / iCloud container; each developer can test with their own two devices. The shared-container question stays [Open] in tech.md
- An iCloud share link opened on a phone without the app shows an iCloud web page that points to the App Store (F2 "app not installed" edge case)

## Implementation findings
- CloudKit room service: `Core/Services/RollRoomService.swift` (`RollRoomServicing` protocol, `CloudKitRollRoomService`, `RollRoomLocation`). Zone-wide share (`CKShare(recordZoneID:)`, read/write for anyone with the link); zone records are read with `recordZoneChanges` so no query index is needed in CloudKit Console
- Removing someone uses the creator of their `RollParticipant` record to find them in the share. A removed participant's next refresh fails on the shared zone; if the roll code record still exists it is "removed", otherwise "deleted"
- `CloudKitSessionService` now reads/writes the room's `RollSession` in the zone (host: private, participant: shared) for start / end / host handover / last-shot race; its old public-database room code (`fetchOrJoinSession`, public `RollSession`, unsaved `CKShare`) is removed. Shot uploads (`RollShot`) are unchanged (public database)
- `CaptureSession` gained `ckZoneOwnerName` (optional, CloudKit-compatible)
- `.xcodeproj`: only `INFOPLIST_FILE = ScrapIt-Info.plist` added. The two keys have no `INFOPLIST_KEY_` build setting, so they live in a small partial plist at the repo root (`ScrapIt-Info.plist`, outside the synced app folder so it is not copied as a resource) that Xcode merges with the generated Info.plist; verified in the built app
- Scene delegate `ShareAcceptingSceneDelegate` (set from `AppDelegate`) receives share links on cold launch and while running; `IncomingShareInbox` hands them to `MainTabView` once signed in. `AppDelegate` registers for remote notifications and posts `.rollRoomDidChange` for CloudKit pushes; the lobby refreshes on that and every 4 s as fallback
- Lobby avatar grid is a plain (non-lazy) 3-column layout; initials alternate between the two Figma styles (surface/ink, burgundy/paper) by user ID [Draft]
- New shared button `CircleIconButton` / `CircleIconLabel` (`Core/DesignSystem/`), same look as `BackCircleButton`, for close / invite / share / "⋯"
- Roll code font: Figma uses Share Tech Mono (not bundled); the system monospaced font is used
- `QRCodeBracketView` and `QRCornerBracketsShape` deleted (QR removed)
- Join error for iCloud problems added [Draft]: "Couldn't join. Make sure you're signed in to iCloud and try again."
- Tests: 102 tests in 11 suites pass (`RollRoomTests` new: 26 with a fake room service), 1 known issue (toggle contrast from 003). Simulator renders of lobby (host / participant), invite sheet, join and avatars compared with Figma. Real CloudKit sharing (accept, AirDrop, push) cannot run in the Simulator without iCloud: device check needed
- Device test 1 (user): "Copy link" copied only the roll code and the share button stayed disabled, i.e. the iCloud link was never created (`createRoom` failed and the error was swallowed). Fixes: errors are logged (`Logger` subsystem "ScrapIt", category "RollRoom") and shown in the Invite sheet with "Try again" [Draft] ("Couldn't create the invite link. Check iCloud and your connection, then try again."; DEBUG builds add the raw CloudKit error); the sheet retries creation while the link is missing; records are saved with `.allKeys` so a retry can overwrite a half-finished attempt; if the roll-code record fails the link is still used; if the saved share has no URL it is read back. Root cause still to be read from the DEBUG error on device
- Device test 2 (user): "Bad Container" — `CKContainer.default()` always uses `iCloud.<bundle ID>` (`iCloud.com.Brian.ScrapIt`) while the entitlements listed `iCloud.Brian.ScrapIt`; the user switched the entitlements container to `iCloud.com.Brian.ScrapIt` (the old public-database shot upload / slot code had the same silent problem). Then "Quota Exceeded": the Apple ID's iCloud storage was full (rooms are stored in the host's private database; SwiftData photo sync from 006 also uses it); the user cleared it. Not syncing roll photos to iCloud is a separate change [Open]
- Device test 3 (user): joining with the same Apple ID as the host showed "Couldn't join…". Both entry points (link and code) now first look for the room zone in the user's own private database (only the host's iCloud has it) and open it there as host; only otherwise the normal join runs. Join / accept errors are logged and DEBUG builds show the raw CloudKit error under the join message
- Device test 4 (user): opening the link from WhatsApp with the same iCloud showed "Couldn't join…" with CloudKit "Operation Cancelled" (20) for both the own-room check and the join. Cause: `MainTabView` handled the link in `.task(id: IncomingShareInbox.shared.pending)`; taking the metadata out of the inbox changed the id and SwiftUI cancelled the running task (and its CloudKit calls). Now handled in `onChange(of:initial:)` with a separate `Task`
