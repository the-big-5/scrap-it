# 019: Lobby "⋯" menu, Invite Friends sheets (AirDrop / room code), Join Roll redesign, join code fixes
Status: Done

## Why
New Figma designs for the roll lobby, inviting friends and joining. Also two problems on Join Roll found on device: a mistyped code character can't be deleted / corrected, and on failure the screen shows a long technical CloudKit error (DEBUG detail) instead of a clear message.

## Touches
ui.md (Create Roll Lobby, Invite Friend Sheet, Join a Roll), flows.md (F2 join, F3 step 4 lobby actions), tech.md (Code structure, assets)

## Changes
### Lobby, host (Figma 1282:21858)
- MODIFIED: the top-right button becomes "⋯" (same style as the participant's) with a menu:
  - **Edit Room**: shown and enabled, but does nothing yet (user decision; the action comes later [Open])
  - **Share Room**: opens the system share sheet directly (the current one: AirDrop link, messaging apps text + link, Mail etc. hidden). No Invite friend sheet in between
  - **Delete Room** (red, destructive): now asks for confirmation first, following HIG (user decision): "Delete this room?" / "Everyone in the room will be removed." / Delete Room / Cancel [Draft text]
- REMOVED: the "Delete roll" text button above Start Roll (moved into the menu)
- ADDED: a "+" tile after the avatars (100 pt grey circle with a plus), **host only**; it opens the Invite Friends sheet
- Avatars stay initials (profile photos still [Open])

### Lobby, participant (Figma 1187:9657, menu 1187:9798)
- MODIFIED: the "⋯" menu has two rows, in this order: **Share Room** (top, same system share sheet) and **Leave Room** (red). Figma's empty top row is not built (user decision)
- No "+" tile for participants; "Waiting for the host to start..." unchanged
- Leave Room keeps today's behavior (no confirmation) [Open: confirm like Delete Room?]. Icon: the HIG "leave" symbol `rectangle.portrait.and.arrow.right` instead of Figma's trash (user decision)

### Invite Friends sheet (Figma 1300:26163)
- Medium sheet: X (close), title "Invite Friends", illustration (two phones on an orange burst, Figma asset), two pill buttons:
  - **Invite via AirDrop**: iOS has no public API to open AirDrop directly, so it opens the system share sheet with **only AirDrop** offered (every other activity excluded), sharing the iCloud invite link. One more tap on a nearby device sends it (user agreed)
  - **Invite via Room Code**: moves to the code page inside the same sheet
- Room code page (Figma 1300:26710): ← back to Invite Friends, title "Invite Friends", "Share this code with your friends to join the roll.", stars illustration (Figma asset), the 6-character code in large spaced letters. **Long-press copies the code** (user decision) with a short "Copied" confirmation [Draft]
- REPLACES the current Invite friend sheet (roll code boxes, Copy link, share button, QR-free sheet from 011)

### Join Roll (Figma 1187:9697)
- MODIFIED layout, following Figma (user decision): back button, title "Join Roll", the two-phones illustration, "Turn on AirDrop to accept the invite", a divider, "Enter code" with 6 boxes, "Join" pill. The old header decoration (camera, film, photo) is removed
- FIXED code entry: one hidden text field holds the whole code; the 6 boxes only display it. Backspace always deletes the last character (also from an empty-looking box), tapping any box opens the keyboard at the end, typing in the middle no longer overwrites the start, pasting a 6-character code fills all boxes. Letters / numbers only, uppercased, max 6
- FIXED messages: the user only sees a short, clear message; technical CloudKit details go to the Xcode console (`Logger`) for developers, never on screen (also not in DEBUG builds)
  - Before contacting the server: fewer than 6 characters → "Enter all 6 characters of the code" [Draft]; the Join button stays tappable
  - From the server (unchanged texts): "No roll found for this code", "This roll has ended", "You're offline. Connect to the internet to join.", "Couldn't join. Make sure you're signed in to iCloud and try again."
  - The message clears when the code is edited

### Assets
- Download from Figma (read-only): two-phones illustration (used in the Invite Friends sheet and Join Roll) and the stars illustration (room code page), into `Assets.xcassets/Invite/`

## Tasks
- [x] Download the two illustrations from Figma into `Assets.xcassets/Invite/` (check: present and used in the right places)
- [x] Host "⋯" menu (Edit Room no-op, Share Room → system share sheet, Delete Room → confirmation → delete); remove the "Delete roll" text button
- [x] Participant "⋯" menu: Share Room, then Leave Room
- [x] "+" tile for the host → Invite Friends sheet
- [x] Invite Friends sheet: AirDrop-only share sheet; room code page with back, long-press copy
- [x] Join Roll: new layout; single-field code entry; local validation; user-facing messages only, technical detail to the log
- [x] Remove code that becomes unused (old Invite friend sheet pieces, `diagnosed()` on-screen detail)
- [x] Tests (Swift Testing): code entry (type, backspace, edit, paste, filter, max 6), validation message for a short code without a server call, server errors map to the short messages without technical text, AirDrop-only activity exclusions, menu actions (delete needs confirmation, share opens the share sheet), "+" only for the host
- [x] Build and run all tests on Simulator
- [x] Manual check on iPhone: host menu and "+" sheet, AirDrop invite to a second phone, room code page + long-press copy, participant menu order, Join Roll with typos / backspace / paste, wrong code shows only the short message — user confirmed on iPhone ("sudah saya cek semua dan sudah oke"; "+" centering, code box alignment, delete Cancel and the "⋯" shadow fixed after their checks). Participant view checked with a temporary DEBUG toggle (removed); a real participant Leave Room needs a second iCloud and was not reported

## Out of scope
- Edit Room's real action
- Profile photos on avatars
- Opening AirDrop without a share sheet (not possible with public API)
- Changes to how joining works (CloudKit, 011) or to Start Roll

## Open
- Edit Room action
- Leave Room confirmation (Delete Room now confirms)

## Implementation findings
- Assets (`Assets.xcassets/Invite/`, @3x, 432 KB): `InviteHandshake` = two phones (Figma 1300:26564, transparent source image) over the orange burst (1300:26566), composed at the Figma offsets; `InviteStars` = the three stars (1300:27195 / 27196 / 27197) composed at their Figma offsets and z-order. Figma's exports carry the sheet color (#F7F2EB) as background, so it was turned into transparency ("color to alpha")
- Lobby: one "⋯" `Menu` for both roles (`menuOrder(.fixed)`): host Edit Room (`editRoom()`, no-op) / Share Room / Delete Room (`requestDeleteRoom()` → confirmation dialog → `deleteRoll()`); participant Share Room / Leave Room. "+" tile = `LobbyTile.invite` from `lobbyTiles(currentUser:)` (host only), 100 pt `Paper.normalHover` circle with a light 75 pt "+" in `Paper.darker` (Figma 1300:26199). "Delete roll" text button removed
- Share Room / Invite via AirDrop: `shareRoom` / `inviteViaAirDrop` make sure the invite link exists (create it if needed), else show "Couldn't create the invite link…" as an alert. AirDrop-only = `RollInviteContent.airDropOnlyExcludedActivityTypes` (every built-in activity but AirDrop + known messaging / social extensions). iOS can't hide unknown third-party share extensions, so another app could still show in the app row
- Invite Friends sheet (`InviteFriendSheetView`, rewritten): page state `invitePage` (.options / .code) in the ViewModel; the camera screen's info button also opens it on the options page now (`presentInviteFriends()`). Room code: long-press copies, "Copied" for 1.5 s with a success haptic
- Join Roll: `RollFlowViewModel.joinCode` + `updateJoinCode(_:)` (ASCII letters / numbers, uppercased, max 6, clears the message); one invisible `TextField` under 6 `RollCodeBox`es, the next box is outlined while typing. `joinIncompleteCodeMessage` for < 6 characters (no server call). `diagnosed()` removed; CloudKit detail goes to `Logger(subsystem: "ScrapIt", category: "RollRoom")` for join, accept-share and invite-link failures
- Removed as unused: `inviteCopyText`, `joinCodeCharacters`, the old per-box `updateJoinCode(at:with:)`, `RollSessionError.invalidCode`. `RollSessionError.rollAlreadyEnded` was already unused before this change and is left as is
- Tests: 14 new in `RollRoomTests` (code entry, short code, message clearing, short server messages, invite link message, "+" host only, invite pages, share / AirDrop sheets, share error, delete confirmation, AirDrop exclusions). Full suite: 201 tests in 20 suites pass, 1 known issue (toggle contrast, 003)
- Fixes after the first device look (user): (1) the "+" on the invite tile was not centered: a "+" text character sits off-center in its 75 pt line height, so it is now the SF Symbol `plus` at 44 pt light. Figma's 75 is the font size of the character (text box 45 × 75); the visible "+" there is about 38–40 pt, and the symbol at 44 pt gives about the same visible size, always centered, the same on every iPhone (user decision: keep 44, "the same on every phone" is what matters). (2) Join Roll code boxes now start at the left edge of "Enter code" (the boxes were centered over the full-width hidden text field)
- Delete Room confirmation is an alert with visible Cancel and Delete Room buttons (user: the confirmation needs a Cancel). A confirmation dialog opened from a menu can show as a popover without a Cancel button on recent iOS
- TEMPORARY (DEBUG builds only, user request to check the participant lobby on one device): the host's "⋯" menu has "Debug: View as Participant / View as Host", which switches only the lobby's look (`debugViewsLobbyAsParticipant`, `showsHostControls`). Host / participant logic is unchanged (Leave Room does nothing for the host). Removed before the merge (user request); not in the code
- "⋯" button glitch (user, IMG_5644): right after the menu closed, the button's bottom (the 3 pt offset shadow) disappeared for about 2 s. The shadow is outside the 44 pt circle and iOS clips a `Menu` label to its frame during the close animation; the label now has 3 pt bottom padding so the shadow is inside its frame (toolbar row top-aligned so X and "⋯" still line up)
