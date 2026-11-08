# Flows
## F1: Sign in [Locked]
1. User opens app
2. Not signed in: sees Welcome screen, taps "Sign in with Apple"; Apple verifies the Apple Account (Face ID / passcode). Only on success is the profile created (or loaded). Requested data: full name only. Apple sends the name only on the first authorization; when it does, the profile name is set or updated to it. Without a name, a new profile is called "Friend"
3. Already signed in (saved Apple user ID + local profile):
   - Online: checked with Apple on launch. Authorized → straight to Home. Revoked, not found, transferred, or check error → Welcome
   - Offline: straight to Home with local data; the Apple check runs once the network is back, and anything but authorized → Welcome
   - No local profile → Welcome
4. After sign-in (and on every launch), scrapbooks and photos from the user's ended rolls are restored in the background, e.g. on a new phone (change 012). No restore UI
5. Sign out (temporary, on Profile tab until the Profile design is ready): returns to Welcome; local data is kept
Edge cases:
- Cancel: stay on Welcome, no message
- Sign-in fails (including no Apple Account on the device): stay on Welcome with an error message
- No network: cannot sign in (Welcome shows an offline message and the sign-in button is disabled). Already signed in users can still enter (see step 3)
- Needs internet: Create Roll, Join Roll (QR, roll code, share link), invite / share link. Works offline: Home, Profile, viewing scrapbooks and photos, editing captions, Sign Out. How online-only features look and behave while offline: [Open]
- First launch: Welcome
- Apple ID revoked while the app is running: caught on the next launch (no live sign-out)

## F2: Join a Roll [Locked]
1. Friend joins by entering the 6-character roll code (Workbench → camera → "Join a Roll"), or by opening the host's iCloud invite link (from AirDrop or a messaging app), which opens ScrapIt and joins directly. No QR code
2. Friend lands in the lobby as a participant; late joining is allowed while the roll lasts (goes straight to the camera if the roll is live)
3. Codes and links stay valid until the roll ends or the host deletes it
4. Same iCloud as the host (same or another device): opening the link or entering the code goes straight into the room as the host; no error, no extra participant. Joining again never adds the same person twice
Edge cases:
- Code not found, roll ended, offline, iCloud problem: stay on Join Roll with a message
- App not installed: the iCloud link shows Apple's iCloud web page pointing to the App Store

## F3: Roll (real-time shared capture session) [Locked]
1. Host taps the disposable camera on Workbench, taps "Create Roll"
2. Setup step: enters roll name, chooses shot count (24, 36 default, 48, 72) with friendship size guidance ("4-6 friends")
3. Filter step: chooses film filter ("Cinematic 400 Pro 35 Black & White" or "200 Color Print")
4. Lobby: roll title, stats (joined, shots) and participant avatars (initials). Host: top-right button opens the "Invite friend" sheet (roll code, Copy link, share); long-press another person's avatar → Remove; "Delete roll" deletes it for everyone. Participant: "⋯" → Leave roll. X (both) closes the lobby back to the Workbench; the roll keeps existing (reopening it: [Open]). No confirmation dialogs
5. Host taps "Start Roll"; participants see "Waiting for the host to start..." and move to the camera when the host starts
6. Removed participants, or everyone when the host deletes the roll, return to the Workbench with a short message
7. Everyone takes photos (still and Live Photo) at the same time in-app. Slot counts sync live in <50ms via Supabase Realtime broadcast (backed up by 3-second CloudKit polling, change 011). Photos are stored locally at optimized resolution (max 2048px still, 1440px movie, ~1.4 MB total per shot, change 014). Nobody, including the host, sees others' photos during the roll
8. One shared pool of shots; any person's photo uses one shot
9. Roll ends when the shots run out OR the host ends it manually
10. Photos are saved into a new shared scrapbook (others' photos become visible here), and the app opens that scrapbook in the editor (change 013, temporary until the design flow)
Edge cases:
- Network lost mid-roll: photos queue locally and sync later
- Host disconnects: host role passes to the next participant
- Last-shot race: first write wins; the other photo is dropped and that user is told the roll finished

## F4: Profile shelf [Draft]
1. User opens profile → sees the scrapbook covers, newest first. For now a 2-column cover grid like the camera POC (change 013); the Figma book / shelf (1109:4648) comes later
2. Taps a cover → opens the scrapbook editor
3. Long-press a cover → Delete → confirmation → the scrapbook, its pages and the roll's photos are deleted on this phone; restore (012) does not bring it back here. Cloud data is kept, so a new phone restores it again [Open]
Empty state: short text that scrapbooks appear after a roll ends [Draft]. Loading state: [Open]

## F5: Scrapbook creation [Draft]
1. When a roll ends, a new scrapbook is created and opens in the editor (change 013) with one empty page; the user chooses which of the roll's photos (Live Photos included) go on the pages
2. Friends' photos are added to the roll's photo picker as they arrive from the cloud (when the roll ends and on later launches)
3. Editor (temporary, ported from the camera POC; may change with the design): multiple 3:4 pages (add, delete, move), photos moved / resized / rotated, Live Photos loop on the page, page background, stickers, scissors, pencil (PencilKit). No markup (PaperKit needs iOS 26)
4. View mode (swipe pages, no tools): later with the design flow [Open]
5. Only ended rolls create scrapbooks; no empty scrapbook, no renaming
Layouts (pages, positions, cuts, drawings) stay on this device: not restored on a new phone, not shared with roll friends. Collaboration rules and syncing layouts: [Open]
Collaboration rules: [Open]

## F6: Social discovery [Open]
