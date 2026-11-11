# Flows
## F1: Sign in [Locked]
1. User opens app
2. Not signed in: presented with 3 onboarding slides on launch before reaching the Welcome screen (change 074). Completing slide 3 ("Let's Try It") smoothly dissolves to Welcome. User taps "Sign in with Apple"; Apple verifies the Apple Account (Face ID / passcode). Only on success is the profile created (or loaded). Requested data: full name and email. Apple sends the name and email only on the first authorization; when it does, the profile name (unless customized) and read-only email are set or updated. Without a name, a new profile is called "Friend". After sign-in from Welcome, user navigates directly to Home (changes 053, 074)
3. Already signed in (saved Apple user ID + local profile):
   - Online: checked with Apple on launch. Authorized → straight to Home. Revoked, not found, transferred, or check error → Welcome
   - Offline: straight to Home with local data; the Apple check runs once the network is back, and anything but authorized → Welcome
   - No local profile → Welcome
4. After sign-in (and on every launch), scrapbooks and photos from the user's ended rolls are restored in the background, e.g. on a new phone (change 012). No restore UI
5. Sign out (in Edit Profile via "Log out" and confirmation): returns to onboarding slides before Welcome (change 074); local data is kept
Edge cases:
- Cancel: stay on Welcome, no message
- Sign-in fails (including no Apple Account on the device): stay on Welcome with an error message
- No network: cannot sign in (Welcome shows an offline message and the sign-in button is disabled). Already signed in users can still enter (see step 3)
- Needs internet: Create Roll, Join Roll (QR, roll code, share link), invite / share link. Works offline: Home, Profile, viewing scrapbooks and photos, editing captions, Sign Out. How online-only features look and behave while offline: [Open]
- First launch: Onboarding slides before Welcome (change 074)
- Apple ID revoked while the app is running: caught on the next launch (no live sign-out)

## F2: Join a Roll [Locked]
1. Friend joins by entering the 6-character roll code (Workbench → camera → "Join a Roll"), or by opening the host's iCloud invite link (from AirDrop or a messaging app), which opens ScrapIt and joins directly. No QR code
2. Friend lands in the lobby as a participant; late joining is allowed while the roll lasts (goes straight to the camera if the roll is live)
3. Codes and links stay valid until the roll ends or the host deletes it
4. Same iCloud as the host (same or another device): opening the link or entering the code goes straight into the room as the host; no error, no extra participant. Joining again never adds the same person twice
5. Join Roll screen (change 019): "Turn on AirDrop to accept the invite" hint, then the code. The code field accepts letters / numbers only (uppercased, max 6); backspace, editing and paste work
6. While joining (code or invite link), a full-screen Joining overlay shows a film canister pulling its film strip out and in, with status text by wait time; Cancel closes it (a late failure is ignored, a late success leaves the room again; nothing to leave when opened as the host) (change 024)
Edge cases:
- Fewer than 6 characters: "Enter all 6 characters of the code", no server call (change 019)
- Code not found, roll ended, offline, iCloud problem: the Joining overlay closes and Join Roll shows a short message only (an invite link shows the room message); technical detail goes to the developer log, never on screen (change 019)
- App not installed: the iCloud link shows Apple's iCloud web page pointing to the App Store

## F3: Roll (real-time shared capture session) [Locked]
1. Host taps the disposable camera on Workbench, taps "Create Roll"
2. Setup step: enters roll name, chooses shot count (24, 36 default, 48, 72) with friendship size guidance ("4-6 friends")
3. Filter step: chooses film filter ("Cinematic 400 Pro 35 Black & White" or "200 Color Print")
4. Lobby: roll title, stats (joined, shots) and participant avatars (initials). Host (change 019): "⋯" menu → Edit Room (no action yet [Open]), Share Room (system share sheet), Delete Room (asks first, then deletes it for everyone); a "+" tile after the avatars opens Invite Friends (Invite via AirDrop, or Invite via Room Code → the code, long-press copies it); long-press another person's avatar → Remove (no confirmation). Participant: "⋯" → Share Room, Leave Room (no confirmation [Open]). X (both) closes the lobby back to the Workbench; the roll keeps existing (reopening it: [Open])
5. Host taps "Start Roll"; participants see "Waiting for the host to start..." and move to the camera when the host starts
6. Removed participants, or everyone when the host deletes the roll, return to the Workbench with a short message
7. Everyone takes photos (still and Live Photo) at the same time in-app. Slot counts sync live in <50ms via Supabase Realtime broadcast (backed up by 3-second CloudKit polling, change 011). Photos are stored locally at optimized resolution (max 2048px still, 1440px movie, ~1.4 MB total per shot, change 014). Each shot uploads to iCloud in the background right after it is taken (once its shot is confirmed and its Live Photo movie is ready), also when the app is closed (change 020). Nobody, including the host, sees others' photos during the roll
   - During capture, tapping the leading Back button returns to Workbench/Homepage while keeping the roll session active; re-entering resumes capture. Exiting the camera view performs a multi-step return transition (changes 056, 086): cross-fades into the zoomed-in camera with matching exit orientation, silently pops to portrait WorkbenchView underneath, fades out the dark background, and spring-animates the camera element back to its idle position on the cutting mat, restoring the floating tab bar. Tapping the FLIP button triggers an 8-blade mechanical iris diaphragm closure over the preview while smoothly animating the zoom wheel to 1.0x with ratchet tick haptics (sliding hatch covers removed, change 072), reopening the iris after the wheel settles. Host can tap the dedicated End Roll button on the top-right camera deck to end the roll manually (changes 041, 072).
8. One shared pool of shots; any person's photo uses one shot
9. Roll ends when the shots run out OR the host ends it manually
10. Photos are saved into a new shared scrapbook (others' photos become visible here). Everyone (host and participants) sees the Roll Reveal once (change 021): a closed envelope with the roll name and the number of photos on this phone ("Printing your photos…" while friends' photos arrive, the envelope bounces and the count rolls up; "Your photos are ready!" for 2.5 s when all are in, change 024) → swipe across the top to tear it open, once every photo is in or 10 s after the reveal opened (change 024) → the photos scatter on a cutting mat (drag to move; "Tidy Up" ↔ "Scatter" switches to a grid by time) → tap a photo for the detail (Save to Photos, a Live Photo as Live Photo; Share; tap outside closes) → "Start Scrapbook" opens the scrapbook editor (change 013). The reveal cannot be opened again
11. After End Roll the phone keeps fetching friends' photos every few seconds until it has all of the roll's shots, for up to 2 minutes; the reveal's count and photos update as they arrive, also after the tear (they land on the mat). Anything still missing comes with the next launch (change 020)
Edge cases:
- Network lost mid-roll: photos queue locally and upload when the app runs online again (launch or reconnect, change 020)
- Host disconnects: host role passes to the next participant
- Last-shot race: first write wins; the other photo is dropped and that user is told the roll finished

## F4: Profile shelf [Draft]
1. User opens profile → sees the scrapbook covers, newest first. For now a 2-column cover grid like the camera POC (change 013); the Figma book / shelf (1109:4648) comes later
2. Taps a cover → opens the scrapbook editor
3. Long-press a cover → Delete → confirmation → the scrapbook, its pages and the roll's photos are deleted on this phone; restore (012) does not bring it back here. Cloud data is kept, so a new phone restores it again [Open]
Empty state: short text that scrapbooks appear after a roll ends [Draft]. Loading state: [Open]

## F5: Scrapbook creation [Draft]
1. When a roll ends, a new scrapbook is created; after the Roll Reveal (F3 step 10, change 021) "Start Scrapbook" opens the scrapbook as a book on the desk with one spread (two empty pages, change 025); tapping the book zooms into the spread editor; the user adds the roll's photos (Live Photos included) from the Photos tray (change 022)
2. Friends' photos are added to the Photos tray as they arrive from the cloud (when the roll ends and on later launches)
3. Editor (ported from the camera POC; may change with the design): pages are always editable, tools in the leather tool tray (change 022): scissors, pencil (PencilKit drawing layers), stickers (Travel, Fun), photos, washi tape, cut-out letters, plain text. 3:4 pages shown two at a time (spreads, change 025): swipe the book to turn a page like a real book, swiping past the last spread adds two empty pages; in the edit view X goes back to the book, zoom cycles both pages → left → right, items can cross the gutter on the spread, Who's here lists people per page, undo / redo covers every change; only the two-page spread turns to landscape. Items moved / resized / rotated (pinch or the corner handle), double tap a photo for full screen, Live Photos loop on the page without stopping other apps' music (change 023). No markup (PaperKit needs iOS 26)
4. View mode (swipe pages, no tools): later with the design flow [Open]
5. Only ended rolls create scrapbooks; no empty scrapbook, no renaming
Layouts (pages, positions, cuts, drawings) are stored on this device: not restored on a new phone. Friends who have the same scrapbook open see all toolbar changes live (change 042, 062): photos (single-use per roll across pages until removed), Travel and Fun stickers (including shared single-use sheet slots, slot restoration on removal, and "Take a New Sheet"), letters, text (add/edit/clear), washi, Pencil drawing layers (Last-Write-Wins), Live Photo motion toggles, cuts and cut undo, item transforms/removals, backgrounds, and page add/move/delete; changes made while a friend is away don't reach them later. Undo / redo is sent with the same events (last write wins, change 025). Storing layouts in the cloud and collaboration rules: [Open]
Collaboration rules: [Open]

## F6: Social discovery [Open]
