# 127: Page dots at Figma size, movable tray button, closing the second tray on its own
Status: Done

## Why
- The paper dots (change 025) scale with the page: at the spread width (201 pt) they match Figma, but a zoomed page or an iPad page shows them bigger and fewer. Figma keeps them small and dense at any page size (1274:33449 spread, 1628:38063 zoomed page: r 1 pt dots every 22 pt).
- The round closed tray button (change 022) is stuck in the bottom corner, over the pages sometimes.
- With a tool's second tray open (Figma 1628:38063), only the main tray can be swiped down, which closes both; the user wants to close just the second tray too.

## Touches
ui.md (Scrapbook: Pages, Tool tray)

## Changes
- MODIFIED Paper dots (change 025): r 0.75 pt dots every 16 pt of the page as shown (not scaled with the page), a little smaller and denser than Figma's r 1 pt / 22 pt at the user's request after testing, so a zoomed page, a bigger iPad page and the book view show the same small, dense dots. Two-finger zoom (change 114) still enlarges everything. Other page backgrounds are unchanged.
- MODIFIED Closed tray button in the scrapbook editor (iPhone), like Freeform: it sits in the bottom left or the bottom right corner. Dragging it slides it sideways; let go, it settles in the nearer corner (or the one it was flicked toward). Swiping the main tray down with a lean to the right closes it into the right corner, to the left into the left corner, straight down into the corner it came from. A tap still opens the tray in its usual place. In landscape the same on the tray's side: the bottom corner (default) or the top corner, dragged up / down, and the closing swipe leaning up or down picks the corner. Turning the phone puts it back in its default corner. Not saved between visits.
- MODIFIED Second tray (change 022, Figma 1628:38063): swiping the second tray down closes only it (the tool is put away), the main tray stays open; swiping the main tray down closes both, as now. Same as Edit Cover (change 103).

## Tasks
- [x] Paper dots at a fixed 16 pt / r 0.75 pt
- [x] Closed tray button in two corners: left / right (portrait), bottom / top of the tray's side (landscape); drag snaps to a corner; the closing swipe's lean picks the corner; back to the default on a turn of the phone
- [x] Second tray swipe-down closes only the second tray in the editor (portrait and landscape)
- [x] Tests where logic changes (none: view-only changes, the second tray uses the tested `closeSubTray`); build and run all tests (378 passed); test on device

## Notes
- A closing swipe leaning more than 12 pt to one side sends the button to that corner, from either corner; the swipe has to start downward (a sideways start scrolls the tray).
- First built as free placement anywhere on screen, then changed to the Freeform-style left / right corners after testing (a misunderstanding). A drag doesn't open the tray, a tap does.
- Only the paper dots' size and spacing changed (`PageBackgroundView`, `.paperDots`); the other backgrounds draw as before.

## Out of scope
- iPad's floating tray (it already moves, change 107), Edit Cover's fixed tray
- Tray contents, tools, other page backgrounds (lined, grid, dotted, plain)
