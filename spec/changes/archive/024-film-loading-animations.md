# 024: Film loading animations for CloudKit waits
Status: Done

## Why
Some CloudKit waits are long and show nothing, so the app looks frozen:
- **Invite link:** opening an invite link shows no screen until the lobby opens.
- **Join with code:** after tapping Join, nothing changes until CloudKit answers.
- **Roll Reveal:** the envelope count climbs slowly while friends' photos arrive (up to 2 minutes). The user can tear the envelope before every photo is in.

The waits should feel like part of the film camera, not a plain spinner.

Assets: only real Figma exports already in `Assets.xcassets`, no screenshots:
- `FilterCanisterBW` and `FilterCanisterColor` (Choose Filter canisters);
- the Roll Reveal envelope layers (change 021).

If an asset turns out to be missing, it is exported from its Figma node with `download_assets`. The canisters have no film, so the strip is `Loading/FilmStripAmber` (SVG, Preserve Vector Data), exported from MID-Fi "Vintage Amber Film Strip" (1235:20885) with its Figma background rect removed.

## Touches
flows.md (F2 Join a Roll, F3 step 10 Roll Reveal), ui.md (Join a Roll, Roll Reveal, new Joining overlay)

## Changes
### Joining overlay (invite link and join with code)
- ADDED A full-screen "Joining" overlay over the current screen. It shows from the moment the join starts until the lobby or camera opens, or the join fails:
  - **Animation:** a film canister bobs and pulls its film strip out and back in. It switches between the B&W and Color canisters every cycle, since the roll's filter isn't known yet.
  - **Background:** cream background (`Paper` scale).
  - **Status text** under the animation changes with the wait time [Draft text]:
    - 0 s: "Finding the roll…"
    - 3 s: "Loading the film…"
    - 8 s: "Almost there…"
  - **Cancel button:** closes the overlay and goes back to where the user was.
    - A failure that arrives later is ignored (no error shows).
    - A success that arrives later opens nothing. The app leaves the room on its own (`leaveRoom`, as Leave Room does), so the user's name doesn't stay in the host's lobby. If the user turned out to be the host (same iCloud), nothing is left.
  - **Failure:** the overlay closes and the existing message shows, as today: on Join Roll under the code boxes; for a link, the existing room exit message.
  - **Reduce Motion:** the canister doesn't move; the film strip only fades in and out.
- MODIFIED Join with code and opening an invite link (iCloud share or `?code=` URL) both use this overlay.

### Roll Reveal: developing envelope
- ADDED While friends' photos are still arriving:
  - **Waiting text:** a small "Printing your photos…" text under the envelope, like a disposable camera's roll at the photo lab [Draft text].
  - **New photo:** the envelope gives a small bounce and the count rolls up like an odometer (digits slide up).
- MODIFIED The envelope can be torn only when every photo is in. "Every photo is in" means:
  - the photos on this phone equal the roll's shots used, **or**
  - 10 s have passed since the Roll Reveal opened, so the user never waits long.

  The End Roll sync keeps fetching for its full 2 minutes (change 020) after the tear too: photos that arrive later land on the mat and in the Tidy Up grid (change 021). A friend's shots that already uploaded arrive even if their phone is off. A shot whose upload hadn't finished (phone off or offline right after the photo, or a force-quit) only arrives when that friend is online again; this phone then gets it on a later launch (restore, change 012).

  Until then the tear strip springs back when dragged and there is no heavy haptic.
- MODIFIED When every photo is in, the text changes to "Your photos are ready!" for 2.5 s, then disappears; the envelope can be torn as today [Draft text]. When the tear unlocks after 10 s with photos still missing, the text just disappears (nothing says ready).
- Reduce Motion: no bounce; the count changes without rolling.

## Tasks
- [x] RollFlowViewModel:
  - `isJoining` state with a status step from the elapsed time;
  - `cancelJoin()`;
  - after Cancel, ignore a late failure, and leave the room after a late success (not when opened as host);
  - join with code, `acceptIncomingShare` and `handleIncomingURL` set it.
- [x] `JoiningOverlayView` (canister + film strip animation, status text, Cancel), shown above the app shell while joining
- [x] RollRevealViewModel:
  - the roll's shots used and the time the reveal opened (10 s unlock);
  - `isDeveloping`;
  - `canTear` (tear ignored while developing);
  - a trigger for each new photo.
- [x] RevealEnvelopeView:
  - "Printing your photos…" text, then "Your photos are ready!" for 2.5 s;
  - bounce on a new photo;
  - odometer count;
  - the tear strip springs back while developing.
- [x] Reduce Motion variants
- [x] Unit tests:
  - join status steps by time;
  - Cancel ignores a late failure, and leaves the room after a late success;
  - failure closes the overlay with the existing message;
  - developing state and tear lock until all photos are in or 10 s have passed;
  - a photo arriving after the tear still lands on the mat.
- [x] Build and run all tests on the simulator

## Out of scope
- Loading for creating the room / invite link, app launch and scrapbook restore (later change)
- Making CloudKit faster; the deferred faster envelope fetch (1 s interval or Supabase signal)
- Cancelling the CloudKit request itself (it can't be stopped; a late success is undone with Leave Room instead)
- Screenshots as assets
