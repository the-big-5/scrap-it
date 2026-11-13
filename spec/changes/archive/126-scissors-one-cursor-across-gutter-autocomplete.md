# 126: Scissors: one pair on the spread, cutting across the gutter, auto-complete
Status: Done

## Why
- On the two-page view each page has its own scissors overlay, so one finger on each page shows two pairs of scissors.
- A cut only reaches items of the page that's active, so the part of an item over the other page (change 104) can't be cut.
- A cut only works when the stroke runs edge to edge. A stroke that stops short, or a rough circle in the middle of a photo, cuts nothing.

## Touches
ui.md (Scrapbook: Scissors)

## Changes
- MODIFIED Scissors on the two-page view (change 022, 025): one scissors overlay over both pages, so there is only ever one pair of scissors. A zoomed page keeps its own overlay.
- MODIFIED Cutting across the gutter: the cut stroke is matched against the items of both pages in their shared layer order (change 104), front first; the frontmost photo the stroke cuts is cut, whichever page it belongs to and on either side of the gutter.
- ADDED Auto-complete:
  - A stroke that enters a photo from an edge and stops inside it is continued straight, in the direction of its last movement, to the photo's edge, and then cuts as a full stroke.
  - A stroke whose end comes back near its start (a rough loop, the ends don't need to meet) closes itself: the part inside the loop becomes its own piece, and the rest of the photo stays with a hole where it was. Both pieces move separately, as other cut pieces.
  - Strokes that already run edge to edge cut as now.
- UNCHANGED Undo / redo and live sync of cuts (the item's new mask plus the new pieces).

## Tasks
- [x] One scissors overlay over both pages on the two-page view
- [x] Cut path in spread space, matched against both pages' items in layer order
- [x] Auto-complete: extend an open stroke to the edge; close a loop into an inner piece and a holed remainder
- [x] Tests (geometry: extension, loop, existing cuts; spread cut across the gutter); build and run all tests (378 passed); test on device

## Notes
- Loop rule (in the photo's own size): the stroke is at least 30% of the photo long, its end comes back within 20% of its start (and within 35% of its length), and the whole loop is inside the photo. Otherwise an unfinished stroke is continued straight to the edge. A stroke that never touches a photo is never completed.
- The holed remainder is still one polygon: the hole is joined to the outline by a zero-width bridge (opposite winding, so a nonzero fill leaves it empty). The mask shape draws outline and hole as two rings, so the selection outline shows no bridge. The synced mask format is unchanged.
- "Page full" now only shows when the stroke was on a photo of that full page (before: on any stroke while the active page was full).

## Out of scope
- Long-press / two-finger move with the scissors, the scissors hint, cutting stickers or other kinds
- The 40-item page limit (unchanged: pieces count)
