# 114: Zoomable pages, easier pencil color picker, eraser sizes, size panel above the picked tool
Status: Done

## Why
- Small details on the pages are hard to place or draw; the user wants to zoom the pages with two fingers.
- The pencil color circle is hard to tap in the scrapbook editor and in Edit Cover: only a nearly invisible system color swatch on top of it takes the tap (`ColorWell`, opacity 0.02), not the whole circle.
- The eraser uses the pencil's size panel (stroke sizes and opacity); Figma now has its own eraser size panel (1628:48361).
- The size panel always opens at the bottom left; the user wants it right above the picked tool, like Apple Notes.

## Touches
ui.md (Scrapbook: edit view, Pencil)

## Changes
- ADDED Page zoom in the edit view (two-page view, left page, right page): pinch with two fingers on the paper zooms the pages, 1×–5×, centered on the fingers, spreading over the dark area around the pages (under the buttons and the tray); the pages stay zoomed after the fingers lift; two fingers pan while zoomed; double tap on empty paper goes back to 1×. Pinch on an item still resizes the item. While Pencil is on, one finger draws and two fingers zoom / pan, like Notes. The zoom goes back to 1× when the zoom button switches view (spread → left → right) or when leaving the edit view.
- MODIFIED Pencil color circle (change 022): the whole 52 pt circle is the button; a tap opens the system color picker in a sheet (as the cover color button, change 026). Same in the scrapbook editor and Edit Cover.
- ADDED Eraser size panel (Figma 1628:48361): tapping the active eraser opens its own panel: stitched red leather, five circle sizes (the picked one on cream), no opacity slider. The eraser widths stay as now (five levels).
- MODIFIED Size panel position (change 022): in portrait the pencil and eraser panels open right above the picked tool in the tray, like Notes. In landscape they stay at the bottom beside the tray, about 60 pt above the screen's bottom edge (change 113). They appear with a plain fade.

## Tasks
- [x] Pinch-to-zoom and two-finger pan on the pages (spread, left, right), 1×–5×, double tap on empty paper resets; item pinch unchanged; works while Pencil is on; reset on zoom-button change and on leaving
- [x] Pencil color circle: whole circle is a button opening the system color picker sheet (editor and Edit Cover)
- [x] Download the eraser size assets from Figma 1628:48361; add the eraser size panel (see Notes)
- [x] Portrait: size panels open right above the picked tool
- [x] Tests where logic changes (zoom); build and run all tests (354 passed); test on device

## Notes
- Eraser sizes: the Figma SVGs were downloaded and checked. Sizes 1–4 are cream circles; the size 5 image has the picked look (white square, red circle) baked in. Because the picked look moves to any size, the five circles are drawn in code from the Figma sizes (radius 5 / 6.5 / 7.42 / 9.5 / 10.5, cream `#FCFBF9` 2 pt; picked: white rounded square r 6.8, `#AE1C1C` 3 pt). The SVGs are not in the project.
- Zoomed in, the pages spread over the dark area around them, under the top bar / buttons and the tray (asked while testing).
- The size panels appear with a plain fade (asked while testing).
- Zoom up to 5× (was 3×, asked while testing).
- Button tap areas (asked while testing): buttons whose size and background were set outside the label only took taps on their title. Fixed in `BookStarCard` (scrapbook confirmation cards: Back, …), the Cancel of the joining overlay and Close of the full-screen photo. Other popups (End Roll, Roll Complete) and `.ds` buttons already took the whole shape.
- Scissors and washi take the touches on the pages while they're on, so the pages don't zoom then; Pencil zooms with two fingers.
- The zoom pinch gives up as soon as one finger moves alone: PencilKit doesn't start a stroke until other pinches on the canvas have failed, so a plain pinch stopped Pencil from drawing.

## Out of scope
- Zoom in the book view (also the read-only book after Done: postponed, page turning while zoomed is undecided), the cover screen, Edit Cover (spine zoom was tried in this change and removed at the user's request)
- Landscape size panel position (stays as change 113)
- Pencil tool images, colors, opacity slider design
