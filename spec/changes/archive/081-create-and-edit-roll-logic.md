# 081: Create and edit roll: Edit Roll, Next validation, filter carousel, new invite art, Delete Roll cards, Continue Roll
Status: Done

## Why
- Edit Room in the lobby has no action yet [Open]; Figma now has the Edit Roll screens (1599:49098 → 1599:49590 → 1600:49849).
- Create Roll lets the user go on without a name, and 36 shots is preset; the user wants a deliberate choice and a disabled Next until both are set.
- The filter step only shows photos on the picked film; Figma 1571:48191 shows both, the picked one moving and larger.
- New invite illustration (1599:49022) for Invite Friends and Join Roll (1187:9697).
- Delete uses a system alert; Figma has its own cards (1600:50620 confirm, 1600:50745 done).
- Reopening a started roll from Resume Roll jumps straight into the camera; the user wants the lobby with "Continue Roll" (1672:29659), so "Start Roll" (and its upcoming animation) only happens once.

## Touches
flows.md (F3 steps 2–5, Resume Roll), ui.md (Create Roll Setup, Create Roll Filter, Create Roll Lobby, Invite Friends Sheet, Join a Roll, Workbench message)

## Changes
- MODIFIED Create Roll Setup (F3 step 2): no shot count is picked at first (no 36 default). "Next" is disabled, in the disabled button color, until the name has text (not only spaces) and a count is picked. The guidance under the strip follows the pick: 24 → "suitable for 2-3 friends", 36 → "4-6 friends", 48 → "7-8 friends", 72 → "8+ friends"; nothing shows before a pick.
- MODIFIED Shot picker (Create Roll and Edit Roll, Figma 1187:8290 / "Shot Picker" 1717:63264, added after the first merge): the picked frame is `Brand.primary` with a white 34 pt heavy number and four viewfinder corner brackets (14 pt, 8 pt in from the corners, assets from Figma); the others are `Kraft.darker` with a 30 pt heavy number in `Paper.dark`; 2 pt black between frames; 80 pt high; a light selection haptic; VoiceOver "<n> shots", selected trait.
- MODIFIED Create Roll Filter (F3 step 3, Figma 1571:48191): title "Create Roll" with ‹, "Pick a filter", both films show their sample photos. The picked film's photos move by themselves like a carousel and its canister grows; the other stays still at normal size. The button is "Done" (goes to the lobby, as "Next" did).
- ADDED Edit Roll (host, lobby "⋯" → Edit Room, Figma 1599:49098): only while the roll hasn't started.
  - Edit Roll setup (1599:49590): ‹, "Edit Roll" (large title), "Capture moments with limited shots, revealed when the roll is complete.", "Name your roll" field and "Pick how many photos to shot" strip with the roll's current name and count, the same guidance and Next validation.
  - Next → Edit Roll filter (1600:49849): as the Create Roll filter, title "Edit Roll", the roll's current filter picked; "Done" saves name, shots and filter to the roll and goes back to the lobby. Friends in the lobby see the new name, shots and filter.
  - ‹ on the filter goes back to the setup; ‹ on the setup goes back to the lobby without saving.
  - Once the roll has started, Edit Room isn't in the menu.
- MODIFIED Invite Friends sheet and Join Roll (1599:49022, 1187:9697): the two-phones-and-stars illustration replaces `InviteHandshake`; assets downloaded from Figma (SVG / PNG).
- MODIFIED Join Roll button (Figma 1663:46361): "Join Roll" (was "Join"), disabled until all 6 characters are in, so "Enter all 6 characters of the code" no longer shows; the message under the boxes is left for a code with no roll ("No roll found for this code") and the other join failures (offline, ended).
- MODIFIED Delete Roll (lobby "Delete Room", Resume Roll long-press "Delete Roll"): a card like the scrapbook cards (washi, star) instead of the system alert (Figma 1600:50620): "Delete Roll?" / "This roll will be gone for good and you won't be able to get it back." / "Keep Roll" (dark) and "Delete Roll" (light, red text). After deleting, the Workbench shows the "Roll Deleted" card (1600:50745): "All set. Start a new roll whenever you're ready.", no buttons, gone after about 2.5 s or on tap. People in the roll the host deleted see the same card (instead of "This roll was deleted").
- MODIFIED Resume Roll → a started (live) roll (F3 step 4, Figma 1672:29659): opens its lobby for host and participants, with "Continue Roll" instead of "Start Roll"; Continue Roll goes into the camera without the start step (the start animation of change 110 only plays on Start Roll). A roll that hasn't started stays as now ("Start Roll" for the host, waiting text for participants).

## Tasks
- [x] Setup: no default count, Next disabled until name + count, guidance per count
- [x] Filter: both films with photos, picked one auto-scrolling and larger; "Create Roll" title, "Pick a filter", "Done"
- [x] Edit Roll: Edit Room → setup → filter → Done saves (name, shots, filter) and syncs; ‹ behavior; no Edit Room after start
- [x] Download the invite illustration from Figma 1599:49022; use it in Invite Friends and Join Roll
- [x] Delete Roll card (1600:50620) for lobby and Resume Roll; Roll Deleted card (1600:50745) on the Workbench for the host and the removed people; download the star assets from Figma
- [x] Shot picker: viewfinder brackets on the picked frame (assets from Figma), Figma sizes and colors, haptic, VoiceOver
- [x] Resume Roll: live roll → lobby with Continue Roll → camera without the start step
- [x] Tests (validation, guidance, edit save, continue vs start); build and run all tests (378 passed); test on device

## Notes
- Next / Done use the design system's primary button, which has the Figma disabled look (Create Roll's Next was the white offset pill). The filter step has no header decoration, as in Figma 1571:48191.
- The drafts are cleared after a roll is created, so the next Create Roll starts with no name and no count.
- Edit Roll saves name, shots and filter to the room's session record in CloudKit (`publishRollDetails`); friends' lobbies pick them up on their next refresh.
- A participant's lobby moves to the camera only when the roll starts while they wait there; a started roll reopened from Resume Roll waits for Continue Roll.
- The star card moved to Core as `StarCard` (shared by Scrapbook and Roll); `BookStarCard` is now a type alias, so the scrapbook code didn't change. It gained a destructive button style (light, red text), sizes for the star and text, and no-button cards.
- Assets from Figma: the two star characters (cut at 3× from the Figma star sheet, as `BookConfirmStar` was), the invite phones image; the washi is the existing `BookConfirmWashi` (same shape and color, pre-rotated). The invite illustration is the three Figma layers placed as in 1599:49022.
- Asked while testing: the filter strip took the width of its looping photos and pushed the canister and "Pick a filter" off screen (and stretched Done); the strip now takes the screen's width and cuts the photos at its edge, on every device.
- Joining with the code of a deleted roll still shows the "This roll was deleted" alert (not part of the roll).
- Tests: Roll tests that only need a lobby now fill a name and a count first; the Workbench test expects the lobby for a started roll.

## Out of scope
- The Start Roll animation (a teammate's change)
- Create Roll Setup layout beyond validation and guidance; lobby avatar grid, invite flow, Leave Roll
- Editing a roll after it started
