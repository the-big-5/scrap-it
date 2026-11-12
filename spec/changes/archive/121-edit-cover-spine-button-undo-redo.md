# 121: Edit Cover: spine button, done check, undo / redo; Leave popup copy; Add page instead of endless pages
Status: Done

## Why
- Edit Cover (change 026) has a "→" button on the front to go to the spine and a "✓" only on the spine. The new Figma (front 1444:23793, spine 1515:27196) makes it clearer: a labeled "Edit book spine →" button, the same "✓" on both sides, and undo / redo.
- The Back popup of the book view (change 025) still shows the Figma placeholder copy; Figma 1533:25816 now has the final copy.
- Swiping past the last spread adds two pages right away (change 025), so pages pile up without the user meaning to, and they can't tell an existing spread from a new one. Figma 1662:27296 asks first.

## Touches
ui.md (Scrapbook: Edit Cover, book view), flows.md (F4 step 3: pages)

## Changes
- MODIFIED Edit Cover top bar (Figma 1444:23793 / 1515:27196): no "Edit Cover" title. Right side on both sides: Editing Progress (the people button, same sheet as on the cover screen), Undo, Redo (disabled at the latest change), ✓ (done with the cover, as the spine's ✓ today). The spine also has ‹ at the top left: back to the front cover, edits kept.
- MODIFIED Front cover: the "→" button becomes the "✓"; a dark pill "Edit book spine →" under the top bar on the right opens the spine.
- ADDED Undo / redo in Edit Cover: front and spine items (stickers, washi, letters, text, pencil layers) and the cover color. The history starts empty each time Edit Cover opens. Synced to friends as the other cover changes (change 026).
- MODIFIED Adding pages in the book view (change 025, Figma 1662:27296): swiping past the last spread no longer adds pages. It turns to a blank spread that isn't saved, with "Need more space?" (15 pt semibold) and a dark "+ Add page" pill (33 pt high) on the right page. Tapping "+ Add page" adds two empty pages there: the prompt goes away and the spread is the new pages, ready to tap and decorate. Swiping back without tapping adds nothing; swiping to the end again shows the prompt again. Tapping elsewhere on that blank spread does nothing, and its right page doesn't turn: "+ Add page" is the only way on; once the pages are added, the book turns past them again. A finished or locked book has no Add page spread (as now: it never adds pages). Friends get the new pages as before.
- MODIFIED Back popup of the book view (change 025, Figma 1533:25816): "Leave the scrapbook?" / "Your changes are saved. You can come back and continue editing anytime." / "Cancel" and "Go to Home" (was the placeholder "Back to … ?", "Yes"). "Go to Home" goes to the Craft tab, also when the scrapbook was opened from another tab (before: back to the start of the current tab).

## Tasks
- [x] Edit Cover top bar: remove the title; Editing Progress, Undo, Redo, ✓ on both sides; ‹ on the spine back to the front
- [x] Front: "Edit book spine →" pill button to the spine
- [x] Undo / redo of front and spine items and the cover color; history starts empty on opening Edit Cover; tests
- [x] Back popup copy from Figma 1533:25816
- [x] Book view: Add page spread past the last spread instead of adding pages on swipe; "+ Add page" adds two pages; tests
- [x] Build and run all tests (358 passed); test on device

## Notes
- Asked while testing: more room between "Edit book spine →" and the front cover (24 pt).

## Out of scope
- The cover screen (closed book), the tool tray and tools of Edit Cover, the color picker
- Back popup layout, star, washi
- Removing pages, a page limit
