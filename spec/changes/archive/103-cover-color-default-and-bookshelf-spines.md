# 103: Blue default cover, cover color in the book view, and bookshelf spines from Edit Cover
Status: Done

## Why
- Change 026 made the cover white by default, but the Figma book (1444:23742) is blue, and the book view still drew a fixed navy cover that ignored the color picked in Edit Cover.
- The Profile bookshelf (change 088) still shows each scrapbook as a palette color with the roll name. What the user made on the spine in Edit Cover (change 026) should be what stands on the shelf.

## Touches
ui.md (Scrapbook: Edit Cover, book view; Profile bookshelf), tech.md (Scrapbook data model)

## Changes
- MODIFIED Default cover color: the blue of the Figma book, `#303D6E` (average of the Figma cover image), instead of white, so a cover starts blue when the user opens Edit Cover.
- MODIFIED Book view (change 025): the cover behind the open pages uses the scrapbook's cover color with the cover grain and inner shadow, so a color picked in Edit Cover (also by a friend) shows when the book is opened.
- MODIFIED Bookshelf spines (change 088): each spine is the scrapbook's own spine from Edit Cover: the Edit Cover spine art (`BookSpineArt`, Figma 1515:27196) in the cover color, with the spine's items (pencil, stickers, text) on top, read only. No roll name and no palette color.
- ADDED Scrapbook field "cover color picked" (default false). It turns true when someone picks a color in Edit Cover (on this phone or from a friend's `cover_color` event). While it is false the cover shows the default blue, whatever color is stored; once true, the picked color is shown, white included.
- MODIFIED Old data: scrapbooks saved before this change have "cover color picked" false, so they show the default blue everywhere (shelf, book view, cover screen, Edit Cover); a scrapbook with no spine decorations shows only the color, with no text.
- REMOVED The 12-color spine palette and roll-name title of change 088 (`BookSpineStyle`, `spineStyle(at:)`), replaced by the above; its palette test is replaced by a spine test.

## Tasks
- [x] Default cover color `#303D6E` (model, ViewModel fallback, test) — done before this file was written
- [x] Book view cover in the scrapbook's cover color with grain and inner shadow — done before this file was written
- [x] Bookshelf spine: `BookSpineArt` + the spine page's items, scaled to the shelf spine; no title
- [x] Add "cover color picked" to `Scrapbook`; set it in `setCoverColor` and on a remote `cover_color`; show the default blue while it is false
- [x] Tests: unpicked old white shows blue; a picked white stays white; a friend's pick counts
- [x] Remove `BookSpineStyle` / palette / `spineStyle(at:)` and update `ProfileViewModelTests`
- [x] Build and run all tests

## Notes
- `BookSpineArt` and `Color(coverHex:)` moved from `Features/Scrapbook/Components/BookCoverViews.swift` to `Core/DesignSystem/Scrapbook/BookSpineArt.swift`, so Profile can use them (no cross-feature imports).
- The 088 asset `BookSpineTexture` is no longer used by code; kept (no deletes without confirmation).
- Fixes found while testing (change 026 bugs, asked by the user with this change):
  - Pencil on the front and spine in Edit Cover: strokes were dropped because the drawing layer was looked up only in the book's pages; lookups now include the cover sides, and the drawing event uses page index -1 / -2.
  - Stickers on the spine land at 60% of the spine's width (the sheet size was already as wide as the spine, the largest a sticker can be), so they can still be made bigger, up to the spine's width.
  - Edit Cover second tray (Pencil, Stickers, Washi, Letters options): swiping it down puts the tool away; the fixed main tray stays. A washi roll can only be picked while the Washi tool is out, so the swipe's own tap can't pick washi again after the tray closed.
  - Book editor two-page view (change 025, asked with this change): the tool hint (scissors, pencil, washi) shows once, centered over both pages, instead of over the left or right page.

## Out of scope
- Merging change 088's spec (the teammate's change; 103 notes that it replaces 088's palette and title)
- Front cover on the bookshelf, tapping or opening behavior, shelf layout, delete
- Scrapbooks still being edited stay on the shelf for now; a separate page for ongoing scrapbooks comes in a later change

## Note for change 088 (teammate)
- 088's code is merged but its spec isn't. 103 replaces 088's 12-color spine palette and the roll name on the spine. When 088 is merged into the spec, its Profile bookshelf text should describe spines from Edit Cover (this change), not the palette and title.
