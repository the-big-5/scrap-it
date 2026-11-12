# 104: Smooth item drop across the gutter on the two-page view
Status: Done

## Why
- On the two-page view of the scrapbook editor (change 025), an item dragged from one page to the other looks whole while dragging. When the finger lifts near the middle, it splits in two at the gutter for a moment, then joins again. The user wants the drop to be smooth.
- Cause found in code: while dragging, a page doesn't clip its items (`ScrapbookPageView` clip inset −2000). On release, the drag ends and the item moves to the other page (`commitTransform`). Each page then clips its items at its own edge again, so the part of the item past the gutter is cut off or covered by the other page.

## Touches
ui.md (Scrapbook: book view, edit view, items, pencil)

## Changes
- MODIFIED Items across the gutter (change 025): on the two-page view, an item dropped across the middle stays whole over both pages, like on a real scrapbook. It doesn't split, flicker or jump when the finger lifts. It only moves to the page its center lands on, as before.
- MODIFIED On the two-page view, items of both pages are drawn above both pages' paper, so the part of an item over the other page isn't covered by that page. The pages are still clipped together at the outer edges of the spread.
- MODIFIED Layers (change 022, 025): both pages of a spread share one layer order. Selecting, Bring to Front, a new item and an item moved to the other page go in front of everything on both pages; Send to Back goes behind everything on both pages. Selecting, dragging or moving an item to the other page no longer reorders the other items (before, the whole page holding the selected item was lifted above the other page). Items keep their stored layer number, synced as before; on a tie the left page's item is behind.
- MODIFIED Zoom (change 025): a zoomed page fills the screen width; the other page no longer peeks at the edge. An item (or stroke) across the gutter is cut at the screen edge and shows its part on each page: zoomed left, its left part shows; zoomed right, its right part shows, whichever page it belongs to. Only the zoomed page's items take touches.
- MODIFIED Pencil on the two-page view (change 025): one canvas over both pages, so a stroke can cross the gutter like other items. A stroke belongs to the page it starts on and is stored in that page's drawing layer; the part over the other page shows on the two-page view. One undo step per stroke, also when an eraser stroke changes both pages. A zoomed page still draws on its own page only.
- MODIFIED Book view (change 025): each page shows the items of both pages of its spread in the same layer order, cut at its own edges. On the open book an item (or stroke) across the gutter is whole; while a page turns, the part on the turning page turns with it.
- FIXED Zooming to one page no longer flashes a dark line.
- FIXED Releasing an item no longer flickers at the outer edges of the book or crossfades between the pages. Cause: the trashcan's spring animation was on the whole editor, so the item's move to the other page and the book's clip animated with it (the clip overshot inward). Only the trashcan animates now.

## Tasks
- [x] Two-page view: pages don't clip their items at the gutter; the spread clips at its outer edge
- [x] Two-page view: both pages' paper is drawn below the items of both pages, so overhanging parts stay visible (tap on empty paper still deselects; the item's page still takes touches on the overhang)
- [x] Release across the gutter: no frame where the item is cut, hidden or offset (left → right and right → left)
- [x] Zoomed page: an item across the gutter shows its part on the zoomed page, cut at the screen edge
- [x] Zoomed page fills the screen width (no peek of the other page)
- [ ] No dark line flash when zooming (fix in place; not confirmed separately on device)
- [x] No flicker at the outer edges of the book on release
- [x] Pencil: one canvas over both pages on the two-page view; strokes split by start page; drawing layers show strokes past the gutter; one undo step per stroke
- [x] Tests for the stroke split
- [x] Book view: items across the gutter whole on the open book, cut per page while turning
- [x] One layer order for both pages of the spread (front / back across both pages; items of both pages drawn in one layer); test
- [x] Build and run all tests (341 passed); test on device

## Out of scope
- Edit Cover and the cover screen: they keep their current clipping
- Moving items to pages other than the two on screen, drop rules (which page gets the item, 40-item limit)
- Live sync: friends still get the move as remove + place (change 025)
