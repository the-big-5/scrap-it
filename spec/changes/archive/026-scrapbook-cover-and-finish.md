# 026: Scrapbook cover editing and finishing
Status: Done

## Why
"Done" in the book view (change 025) has no action yet. After decorating the pages, the group dresses the cover, then closes the scrapbook:
- the host saves (locks) it for everyone;
- each participant marks themselves done.

### Figma (MID-Fi)

| Node | Screen |
| --- | --- |
| 1515:29509 | Cover screen, host |
| 1563:33405 | Cover screen, participant |
| 1444:23793 | Edit Cover, front |
| 1515:27196 | Edit Cover, spine |
| 1563:33166 | Editing Progress |
| 1444:23696 | "⋯" menu |
| 1563:33117 | Ready to close? |
| 1563:33675 | Scrapbook Complete |
| 1563:33475 | Nice Work |
| 1563:33594 | Back to Home |

## Touches
flows.md (F5), ui.md (Scrapbook screen, Assets), tech.md (data models, Scrapbook sync, CloudKit room fields)

## Changes
### Cover screen (after Done)
- ADDED "Done" in the book view closes the book and shows the **cover screen**:
  - **Layout:** the green cutting mat and the closed book (front cover with its texture, color and decorations).
  - **Top right:** Editing Progress (person icon) and "⋯".
  - **Bottom:** two buttons.

  | Role | Buttons |
  | --- | --- |
  | Host (1515:29509) | **Edit Cover**, **Save Scrapbook** |
  | Participant (1563:33405) | **Edit Cover**, **Done Editing** |

  - **Host:** the roll's host (`CaptureSession.hostUserID`).
- ADDED **Done is final for the pages:** after Done in the book view the user can't go back to editing the pages. Edit Cover only opens after the pages are done.
  - **Storage:** kept on this phone per scrapbook.
  - **Reopening the scrapbook:** it opens on the cover screen.
- ADDED "⋯" menu (1444:23696): **Save as Video** and **Share**. Both are shown but do nothing in this change:
  - video export comes in a later change;
  - what Share does is still undecided [Open].

### Edit Cover (front and spine)
- ADDED **Edit Cover** (1444:23793): "Edit Cover" title.
  - **Default cover:** white (with the Figma cover texture).
  - **Tray:** the leather tray opens right away with **Pencil, Stickers, Washi, Letters, Text**, fixed: centered, no sideways scrolling, and it doesn't fold away. No scissors and no photos on the cover.
  - **Color picker:** a round button at the bottom right above the tray opens the system color picker in a sheet and changes the cover color. The cover sits higher so it never runs into the button. The cover texture stays visible over any color.
  - **→** (top right): moves to the **spine** (1515:27196).
- ADDED **Spine** (1515:27196): the narrow spine of the book with its own decorations.
  - **Tray:** Pencil, Stickers, Text only.
  - **Text:** typed text on the spine stands upright along it (rotated 90°). Its size can be changed like any text, up to the spine's width.
  - **✓** (top right): finishes Edit Cover, back to the cover screen.
- ADDED Titles are not automatic: the front starts plain. The user adds the title on the front and the spine with the Text tool. Text on the cover (front and spine, and in the typing screen while editing the cover) uses Architects Daughter.
- ADDED Cover items behave like page items: move, resize with the corner handle, rotate, long-press menu, trash. Edit Cover has no undo / redo buttons in Figma, so there is none on the cover.
- ADDED Cover edits are shared live with friends (front, spine and color), like pages (change 062).

### Editing Progress (1563:33166)
- ADDED The person button on the cover screen opens a sheet "Editing Progress" with X:
  - **"Done Editing":**
    - participants who tapped Done Editing;
    - the host, once they tapped Done in the book view (the host has no Done Editing button).

    Me first as "Name (You)".
  - **"In Progress":** the other members of the roll, online or not.

  Avatars as in Who's here (change 025).

### Finishing
- ADDED **Participant — Done Editing:** shows "Nice Work!" / "Hang tight while everyone else finishes editing the scrapbook." / **Got It** (1563:33475).
  - **Status:** their status becomes done for everyone (saved in the CloudKit room and sent live).
  - **Editing:** from then on the scrapbook is read-only for them.
  - **After Got It:** the cover screen shows only **Back to Home** (1563:33594), which goes to the Home tab.
- ADDED **Host — Done in the book view:** the host's status becomes done for everyone (saved in the CloudKit room and sent live).
- ADDED **Host — Save Scrapbook:**
  - **Someone still In Progress:** it asks first (1563:33117): star, "Ready to close the scrapbook?", "Some participants are still editing. If you finish now, the scrapbook will be locked and no one will be able to make further changes.", **Keep Editing** (closes the card) / **Save Scrapbook**.
  - **Everyone done:** it saves right away.
- ADDED **Save Scrapbook** locks the scrapbook for everyone (saved in the CloudKit room and sent live), then shows "Scrapbook Complete!" / "Your memories are all tucked in! Revisit your scrapbook anytime on your Bookshelf." / **View Bookshelf** (1563:33675), which goes to the Profile tab.
- ADDED **Locked or done scrapbook:**
  - **Opening it:** from Profile it opens on the cover screen with **Back to Home**.
  - **Reading it:** tapping the book opens a **read-only** book view: turn pages, no tray, no Done, no editing.
  - **A friend locks it while you edit:** your editor turns read-only and goes to the cover screen with Back to Home.

### Data and sync
- MODIFIED `Scrapbook`:
  - `coverColor` (hex, default white `#FFFFFF`);
  - `isLocked` (+ locked date).
- MODIFIED `Scrapbook`: `hasFinishedPages` (this phone's user tapped Done in the book view).
- MODIFIED `ScrapbookPage`: `role` (`nil` = a normal page, `front` = front cover, `spine` = spine). Cover pages are not part of spreads and page counts.
- ADDED CloudKit room (change 011):
  - the room record keeps `scrapbookLocked`;
  - each `RollParticipant` keeps `doneEditing`.

  Restored when the room is read (offline friends count as In Progress until their status is saved).
- ADDED Supabase Realtime events:
  - `editing_done` (member id);
  - `scrapbook_locked`;
  - `cover_color` (hex).

  Cover items use the existing item events with page index `-1` (front) and `-2` (spine).
- The Profile bookshelf keeps showing the first page for now (the new cover there: later change).

## Tasks
- [x] Assets: export the cover texture and its mottle layers, the color picker button, and the spine art from Figma (`download_assets`, SVG where the node is vector, original PNG where it's a raster; no screenshots)
- [x] Data:
  - `Scrapbook.coverColor`, `isLocked`, `lockedAt`;
  - `ScrapbookPage.role`;
  - create the front and spine pages on first Edit Cover;
  - keep them out of `pages` / spreads.
- [x] ScrapbookViewModel:
  - modes cover screen / edit cover (front, spine);
  - host vs participant;
  - tray tools per cover side;
  - cover color;
  - Done in the book view is final for the pages (host: counts as done);
  - Done Editing;
  - Save Scrapbook (asks first only when someone is still In Progress);
  - read-only when done / locked;
  - Editing Progress rows from the roll members and statuses.
- [x] Views:
  - cover screen (book cover with texture and color, buttons per role, ⋯ menu without actions);
  - Edit Cover front / spine with the open tray and color picker;
  - Editing Progress sheet;
  - Ready to close / Scrapbook Complete / Nice Work cards (reuse the confirmation card of 025);
  - read-only book view.
- [x] Sync:
  - Supabase events `editing_done`, `scrapbook_locked`, `cover_color`;
  - cover item events (page index −1 / −2);
  - CloudKit room fields `scrapbookLocked` and `doneEditing`, read on restore / when opening.
- [x] Navigation: View Bookshelf → Profile tab; Back to Home → Home tab
- [x] Unit tests:
  - host vs participant buttons;
  - Done Editing → read-only;
  - pages can't be edited again after Done;
  - the host counts as done after Done;
  - Save asks first only when someone is In Progress, then locks;
  - lock from a friend turns the editor read-only;
  - cover color saved and sent;
  - cover items on front / spine;
  - spine tray tools;
  - Editing Progress lists;
  - cover pages kept out of spreads.
- [x] Build and run all tests on the simulator

## Out of scope
- Save as Video (later change) and Share (still undecided); both menu items are shown without action
- The new cover on the Profile bookshelf
- Unlocking a saved scrapbook; undoing Done Editing
- Photos and scissors on the cover
