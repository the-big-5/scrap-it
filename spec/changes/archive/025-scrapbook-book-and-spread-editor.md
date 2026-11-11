# 025: Scrapbook book view and spread editor
Status: Done

## Why
The scrapbook should open like a real book on the desk, not straight into a single editable page. The user flips through spreads (two pages), swipes past the last spread to get new pages, and taps the book to zoom in and decorate a spread.

The new edit view replaces the old header:
- **Removed:** page arrows, the presence avatar stack, and the "⋯" menu.
- **New top bar:** close, zoom, who's here, undo and redo.

Undo and redo now cover every change.

### Figma (MID-Fi)

| Node | Screen |
| --- | --- |
| 1444:23742 | Book view on the desk |
| 1518:30319 | Book view with the one-time hint and Done |
| 1274:33449 | Edit view, spread |
| 1537:25210 | Edit view, zoom left page |
| 1536:24095 | Edit view, zoom right page |
| 1516:23450 | Who's here sheet |
| 1563:30642 / 1563:30756 | Landscape, spread |
| 1563:31649 / 1563:30868 | Landscape, tray open |
| 1533:25816 | Back confirmation |

## Touches
flows.md (F5), ui.md (Scrapbook editor → Scrapbook book view + edit view, Assets), tech.md (orientation, undo history, data models)

## Changes
### Book view (opens first)
- ADDED Opening a scrapbook (after the Roll Reveal and from Profile) shows the **book view** (1444:23742):
  - **Desk:** the Workbench desk assets: `DeskWood`, the green `DeskCuttingMat` and `DeskMeasurements`.
  - **Book:** an open book on the mat showing one spread (two dot-paper pages).
  - **Buttons:** Back at the top left; "Done" at the bottom (1518:30319) is shown but does nothing in this change.
- ADDED **Spreads:** pages are shown two at a time (pages 1–2, 3–4, …).
  - Swiping left / right on the book moves between spreads.
  - Swiping left on the last spread adds a new spread of two empty pages and shows it.
  - A new scrapbook starts with one spread (two pages). An existing scrapbook with an odd page count gets one empty page added, so the last spread is full.
- ADDED **One-time hint** (1518:30319): a tooltip under the book, "More pages to fill!" / "You can swipe to another page and decorate it too." with an X.
  - It shows **once per user** (this device): the first time any scrapbook's book view opens.
  - It goes away on X, on a swipe, or when the book is tapped.
- ADDED **Back** shows a confirmation (1533:25816): a card with washi tape and a star character, Cancel / Yes. Yes leaves the scrapbook (back to where it was opened from).
  - The Figma copy is still a placeholder and is used as is for now [Open, waiting for copywriting]:
    - title "Back to … ?";
    - body "Your scrapbook can be saved and continue to be edited later apalah".
- ADDED Tapping the book zooms into the **edit view** for the spread on screen.

### Edit view (portrait, 1274:33449)
- ADDED The edit view opens on the **spread** (both pages) by default. The spread fills the width on a dark background. The leather tool tray (change 022) stays at the bottom left.
- ADDED Top bar, left to right:
  - **X:** back to the book view (same spread).
  - **Zoom:** tap 1 = left page fills the screen (1537:25210); tap 2 = right page (1536:24095); tap 3 = back to the spread. The icon shows the state.
  - **Who's here** (person icon).
  - **Undo** and **Redo.**
- ADDED **Which page an item is on:**
  - **Zoomed to one page:** new items go to that page, and items can't leave it.
  - **Spread:** an item can be dragged across the gutter to the other page. Where it's dropped decides its page; its position is converted to that page's space.
  - **New items on the spread:** they go to the page last touched (left page by default).
  - **Pencil on the spread:** both pages draw directly, each into its own drawing layer (one canvas per page).
  - **Sticker sheet on the spread:** it opens over both pages, and a sticker sticks to the page it's dropped on.
- REMOVED From the editor:
  - page indicator and arrows;
  - presence avatar stack;
  - the "⋯" menu: Background, Add Page, Move Left / Right, Delete Page (all removed; pages are added by swiping in the book view);
  - swiping between pages inside the edit view;
  - the old Undo button.

### Edit view (landscape, 1563:30642 / 1563:30756 / 1563:31649 / 1563:30868)
- ADDED Only the **spread** turns to landscape left and right.
  - **Zoomed to one page:** the edit view stays portrait.
  - **Zoom button:** not shown in landscape.
  - **Layout:** landscape always shows the spread.
  - **Buttons:** a column of round buttons on the side away from the tray (undo, redo, who's here at the top; X at the bottom).
  - **Tray:** the tool tray runs vertically along the other side.
  - **Other screens:** the book view stays portrait (the app stays portrait outside the edit view and the camera).

### Who's here (1516:23450)
- ADDED The person button opens a sheet titled "Who's here", with an X:
  - **"On this page":** people on the same spread, me first, as "Name (You)".
  - **"On other pages":** the others with their page number ("Page 3").

  Each row shows the person's avatar (photo or colored circle with an initial) from the existing presence (change 042 / 044).

### Undo / redo (all changes)
- MODIFIED Undo and redo cover every change made on this phone in the edit view:
  - **Items:** add, move, resize, rotate, delete;
  - **Tools:** scissors cuts, pencil strokes, text add / edit / clear, washi pieces, letters, stickers.
- **One history** per editor visit, for the spread on screen. Redo is disabled at the latest change; a new change clears the redo steps.
- Undo after a friend's live change may overwrite it (last write wins) [Open].

### Data
- MODIFIED Page paper as in Figma (1274:33452): the default page (`cream`) is `#F6F1E7` with faint dots every 22 pt (r 1 pt, `#4F4121` at 10%) and an inner shadow (blur 14.72, black 19%) that also marks the gutter between the two pages, in the book and in the edit view.
- MODIFIED Pages keep their 3:4 shape and 600 × 800 drawing space (Figma pages are about 0.725; 3:4 keeps every existing layout) [Draft].
- MODIFIED `ScrapbookPage` order still gives the spread (page index / 2).
- No new stored fields. The one-time hint flag is kept in `UserDefaults`.

### Assets
- REUSED `DeskWood`, `DeskCuttingMat`, `DeskMeasurements` (Workbench), and the leather tray (022).
- ADDED SVG from Figma (`download_assets`, never screenshots), with background rects removed:
  - the zoom icons (spread / left / right);
  - the who's here person icon;
  - the confirmation's washi tape.
  - SF Symbols are used where Figma uses them (X, undo, redo, back).
- ADDED Star character from the confirmation: the Figma original is a raster image, so it's the original PNG at full resolution, scaled to fit.
- Book cover: the cover design isn't ready. For now the book's edge is a plain dark navy border drawn in code [Open].

## Tasks
- [x] Assets: download the zoom icons, person icon and washi tape as SVG and the star character as PNG; check each against Figma
- [x] ViewModel (ScrapbookViewModel or a book ViewModel in the Scrapbook feature):
  - mode: book / edit;
  - current spread;
  - swipe to next / previous spread, and add a spread past the last one;
  - complete an odd last spread;
  - one-time hint flag (`UserDefaults`);
  - Back confirmation;
  - zoom state (spread by default → left → right → spread);
  - page last touched;
  - moving an item across the gutter on the spread (page change + coordinate conversion);
  - landscape allowed only on the spread.
- [x] Book view (desk, mat, book with the spread, hint, Done without action, Back confirmation) and the zoom transition into the edit view
- [x] Edit view portrait:
  - two `ScrapbookPageView`s side by side;
  - top bar;
  - tools work on the active page;
  - remove the old header, menu and page indicator.
- [x] Edit view landscape:
  - orientation unlock for this screen only (`OrientationLock`);
  - button column;
  - vertical tool tray (main and second tray).
- [x] Who's here sheet from presence (this spread / other pages with page numbers)
- [x] Undo / redo:
  - one history of page snapshots for every change (items, cuts, strokes, text, washi, letters, stickers);
  - redo disabled at the latest change;
  - replaces the cut undo and the pencil-only undo.
- [x] Unit tests:
  - spreads from pages;
  - adding a spread past the last;
  - completing an odd page count;
  - hint shown once per user;
  - zoom cycle;
  - new items go to the zoomed page / last touched page;
  - an item dragged across the gutter on the spread changes page, and can't leave a zoomed page;
  - landscape only allowed on the spread;
  - undo / redo for add, move, delete, cut, stroke and text;
  - redo cleared by a new change;
  - Back confirmation leaves only on Yes.
- [x] Build and run all tests on the simulator

## Out of scope
- What Done does (next change)
- The book cover design
- Final copy for the Back confirmation (copywriting pending)
- Syncing undo / redo or spreads with friends beyond the existing realtime events
- Page background, reordering and deleting pages (removed; may come back with a design)
