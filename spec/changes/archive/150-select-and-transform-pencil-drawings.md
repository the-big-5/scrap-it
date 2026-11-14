# 150: Select a pencil drawing and move, resize, rotate or remove it
Status: Done

## Why
- Pencil strokes (changes 022, 104, 128) can only be erased. A drawing made of several strokes (a star, a handwritten word) can't be moved, resized, rotated or removed as one thing, unlike photos, stickers and text.
- Apple's lasso (`PKLassoTool`) only moves, cuts and copies, with no resize or rotate handle, and works only while drawing.

## Touches
ui.md (Scrapbook: Items, Pencil)

## Changes
- ADDED Selecting a drawing (no tool on: Pencil, Scissors and Washi off): a tap on a pencil stroke on the page selects the drawing it belongs to. Items above the stroke (photos, stickers, text…) still take the tap first; a tap on empty paper deselects, as now. Works on both pages of the two-page view, a zoomed page and the cover sides; not in the read-only view (change 125).
- ADDED What counts as one drawing: the tapped stroke plus every stroke of the same page's drawing layer that overlaps it or comes within 8 pt (at the two-page view's page size, scaled with the page), and so on through their neighbors. The 8 pt is one constant, to tune on device.
- ADDED The selected drawing shows the selection box of the other items (change 022): drag to move, the bottom-right corner handle to resize / rotate with one finger, pinch / rotate with two fingers (rotation snaps to 0° within ±3°, sizes limited like stickers). Dragging shows the trashcan (change 062); dropping on it removes the drawing. Long press: "Remove from Page".
- ADDED Storage and sync: the changes are applied to the strokes' own transforms in the page's drawing layer (removing deletes those strokes), saved in the layer's drawing data. One undo step per move / resize / rotate / removal; friends get it through the existing drawing update (last write wins, change 042). The strokes stay strokes: the eraser still erases them and they don't count toward the 40-item limit.
- ADDED On the two-page view a drawing can be moved over the gutter like other items; it stays in its page's layer (shown across the gutter, change 104).

## Tasks
- [x] Hit test strokes on a tap with no tool on (after items, before "empty paper"), on every page that takes touches
- [x] Cluster strokes (overlap or ≤ 8 pt, transitive) within the page's drawing layer
- [x] Selection box with move, corner handle resize / rotate, pinch / rotate, trashcan and "Remove from Page", writing stroke transforms into the layer
- [x] Undo / redo and live sync through the drawing layer's data
- [x] Tests (clustering, transform applied to the right strokes, removal, undo); build and run all tests; test on device (408 passed, 1 known issue in `DSContrastTests`; tested on device)

## Out of scope
- Bring to Front / Send to Back for drawings (would need a drawing split into its own layer, against change 128's layer merge)
- A lasso or a Select tool in the Pencil tray, selecting several separate drawings at once, copy / paste / duplicate
- Moving a drawing into the other page's layer
- Changing stroke color or thickness after drawing
