# 001: Capture session through basic scrapbook
Status: Done

## Why
Build the core experience first: a multi-user capture session that ends in a new shared scrapbook showing the captured photos.

## Touches
flows.md (F1, F2, F3, F5), ui.md (Welcome, Invite, Capture session, Scrapbook), tech.md (live transport, Session model)

## Changes
- MODIFIED F1: if the user is not signed in, show Sign in with Apple; if already signed in, go straight to Home
- ADDED screens from Figma (see ui.md): Welcome/Sign in, Home (shelves + Home/Profile tabs), Camera Roll (Create/Join), Create Roll steps (name + shots, filter, share room), Capture session (landscape)
- MODIFIED F2/F3: sessions are called Rolls. Host sets a roll name, shot count (24/36/48/72) and a filter, then shares a QR code, 6-character roll code and share link. Friends join by code/QR/link; the host taps Start Roll when ready
- ADDED: film filter choice (B&W / Color) at roll creation
- MODIFIED F2: invite links stay valid until the session ends
- MODIFIED F3 edge cases:
  - Host disconnects: host role passes to the next participant
  - Last-slot race: first write wins; the other photo is dropped and that user is told the roll finished
  - Offline: photos queue locally and sync later (unchanged)
- MODIFIED F5: when a session ends, a new scrapbook is created showing the captured photos in a basic grid (title, cover photo, created date, photos with captions)
- ADDED: live remaining-slot counter and presence list during a session

## Tasks
- [x] BLOCKER, decide first: live transport/backend → Decided: use CloudKit only (`CKShare` + CloudKit records/subscriptions; optimistic concurrency via `CKRecord` change tags for last-slot race; no third-party backend)
- [x] Data models: Profile, Scrapbook, Photo, Session (SwiftData)
- [x] Sign in with Apple, routing to Home if already signed in
- [x] Home screen and Home/Profile tab bar per Figma (Profile tab can be a stub)
- [x] Create Roll flow per Figma: name, shots, filter, share room (QR, roll code, share link, joined count, Start Roll)
- [x] Join a Roll via code, QR or link, late joining allowed (Join screen is NOT designed yet: needs design or approval of a simple stub)
- [x] AVFoundation camera in the landscape camera UI per Figma: flash, Live toggle, zoom, flip, grid, shots counter; each shot consumes a slot
- [x] Live shots counter and joined/presence count (lobby shows count; in-session presence UI not designed)
- [x] End session (roll runs out or host ends); host handover on disconnect
- [x] Offline queue and sync
- [x] Create new scrapbook and show photos in a basic grid

## Open before approving
Design is still in progress, so these are intentionally open. Build only stubs where the design is not final:
- Filter picker: final design is a carousel roll with sample photos per filter; filter application behavior and the list of filters
- Join Roll: placeholder design (QR scan + 6-character code); real design pending
- Capture screen: in-session presence UI and end/roll-finished/offline states
- Scrapbook grid and Profile tab designs
- Other Home shelf objects (only the camera opens Camera Roll)
- Logo asset
- Orientation: the app supports all orientations (the Figma frames are just landscape/portrait mockups)

## Out of scope
- Figma-based visual design (later)
- Collaborative live scrapbook editing, stickers, layouts
- Profile shelf, social discovery
- Public feed, direct messaging, comments, notifications
- Friend list / Friendship model
