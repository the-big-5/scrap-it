# 125: Scrapbook done flow: welcome card, ✓ instead of Done, back to editing, shelf vs Resume Editing, reading the finished book
Status: Done

## Why
- Done in the book view finishes the pages at once (change 026): a tap by mistake and the user can't edit anymore. The cover screen should be the confirmation step, with a way back.
- New Figma: a welcome card on the book (1444:23742), ✓ at the top right instead of the Done button (1518:30319), ‹ on the cover screen (1563:33405).
- The editor's Who's here sheet should be called Editing Progress.
- The Library shelf and Resume Editing both list every scrapbook; the shelf should only hold finished (saved) ones, Resume Editing the rest.
- The finished book can't be zoomed into or zoomed with two fingers like the editor, and after turning to the next page it can't turn back.

## Touches
flows.md (F4: book, cover, finishing; Resume Editing), ui.md (Scrapbook: book view, cover screen, Who's here; Profile bookshelf; Resume Editing)

## Changes
- ADDED Welcome card on the book view (Figma 1444:23742): the star card with washi and the happy star, "Welcome to your scrapbook!" / "Tap the scrapbook to start editing. Add photos, get creative, and make it yours together.", no buttons. Once per scrapbook on this phone, the first time its book opens for editing; a tap anywhere dismisses it.
- MODIFIED Book view (change 025, Figma 1518:30319): the bottom "Done" button is replaced by a round ✓ at the top right. ✓ asks first (Figma 1708:45425): the star card "Done editing your pages?" / "Nice work! Now let's finish it with a cover.", "Cancel" (stays in the book) and "Edit Cover" (opens Edit Cover; its ✓ then lands on the cover screen). This doesn't finish anything yet (the host isn't counted as done, ‹ on the cover screen goes back to the pages).
- MODIFIED Cover screen (change 026, Figma 1563:33405): ‹ at the top left for the host and participants who aren't done: back to the book, editing again. "Done Editing" (participant) and "Save Scrapbook" (host) are what finish, as now. A scrapbook left on the cover screen (✓ but not done) opens on the cover screen again; one that's done or saved opens read only, as now.
- MODIFIED Host status in Editing Progress (change 026): Done while the host is on the cover screen (with Edit Cover and Save Scrapbook), In Progress while on the pages or in Edit Cover, and Done for good after Save Scrapbook. Synced both ways: going back to edit sends "editing_resumed" (realtime) and removes the host's done record from the room in CloudKit; friends' phones take the host's status from the room on refresh. Participants are unchanged (Done Editing is final).
- MODIFIED Editor Who's here sheet (change 025): titled "Editing Progress" (sections unchanged).
- MODIFIED Library shelf (changes 088, 103): only saved scrapbooks (locked by the host's Save Scrapbook).
- MODIFIED Resume Editing (change 104): only scrapbooks that aren't saved yet (also when this phone's user is done editing and waits for the others).
- ADDED Reading a finished book (from the shelf, the cover screen of a saved or done scrapbook): tapping the book zooms into the two-page view like the editor, read only (no tools, no undo, no Who's here); X goes back to the book; two-finger zoom and pan as in the editor (change 114); the zoom button cycles both pages → left → right as in the editor.
- FIXED Reading a finished book: after turning to the next page, turning back works.

## Tasks
- [x] Welcome card once per scrapbook (stored on this phone), tap dismisses
- [x] Book view: ✓ top right instead of Done; ✓ → cover screen without finishing
- [x] "Done editing your pages?" card after ✓ (Cancel / Edit Cover)
- [x] Cover screen: ‹ back to the book (host and participants not done); opening a scrapbook left on the cover screen lands there
- [x] Who's here sheet title "Editing Progress"
- [x] Host Done on the cover screen, In Progress on the pages / Edit Cover (synced both ways)
- [x] Shelf: saved scrapbooks only; Resume Editing: the others
- [x] Finished book: tap → read-only two-page view with X, zoom button and pinch zoom; turning back fixed
- [x] Tests; build and run all tests (374 passed); test on device

## Notes
- Save Scrapbook asks first only while someone other than the host is In Progress.
- Turning back in the finished book: the cause couldn't be reproduced in tests (the ViewModel turns back fine). What was found and fixed: on the last spread of a finished book the right page still lifted as if a next page existed, then fell back; it no longer lifts there. To check on device.
- Reading the pages hides the tool tray, Editing Progress, Undo and Redo, and items can't be touched; the paper still takes the two-finger zoom.
- Tests: the old "Done is final" test became "Done is a confirmation step with a way back"; shelf tests use saved scrapbooks.

## Out of scope
- Edit Cover, Save Scrapbook / Done Editing cards and their rules, Editing Progress sheet (cover)
- Book view zoom by pinch on the closed book (only in the zoomed two-page view)
- Deleting or leaving scrapbooks
