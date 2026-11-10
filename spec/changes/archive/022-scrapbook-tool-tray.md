# 022: Scrapbook tool tray (port from the camera POC)
Status: Done

## Why
The scrapbook editor's text toolbar and the system PencilKit tool picker don't match the Figma design. The camera POC (FilterCam) already built the red leather tool tray from Figma, plus washi tape, cut-out letters, plain text and a second sticker sheet.

Also, the editor's eraser deletes a whole stroke when touched. The tool picker shows the vector eraser first (`PKToolPickerEraserItem(type: .vector)`). Users expect it to erase only the part they swipe over.

Sources:
- POC brief `TBF/POC/Camera/Brief Port Tray Alat Scrapbook.md` (porting guide, Figma nodes, mistakes and fixes F1–F9, K1–K11).
- POC spec `Spec Tray Alat Scrapbook.md` (behavior source).
- Figma file `ujlkuWobqxyvtQwh5plhGF`:

  | Node | Screen |
  | --- | --- |
  | 1306:48941 | Tray closed |
  | 1306:48947 | Main tray |
  | 1306:50774 | Pencil |
  | 1144:25595 | Pen size panel |
  | 1306:50103 / 1306:54411 | Stickers |
  | 1306:49859 | Photos |
  | 1306:49648 / 1306:56097 | Washi |
  | 1306:49157 | Letters |

## Touches
flows.md (F5), ui.md (Scrapbook editor), tech.md (Scrapbook drawing, data models ScrapbookPage / ScrapbookItem / StickerSheet, project structure)

## Changes
### Tray and editor layout
- MODIFIED Scrapbook editor layout. The bottom text toolbar is replaced by a tray:
  - **Closed:** a round red leather button at the bottom left.
  - **Main tray:** tapping the button opens the full-width main tray. Swiping down on it closes the tray and turns off the active tool.
  - **Main tray tools, left to right:** Scissors, Pencil, Stickers, Photos, Washi, Letters, Text.
  - **Second tray:** tapping a tool opens a second tray above the main tray (it overlaps by 18 pt). Tapping the same tool or an empty spot on the page closes it.
  - **Look:** leather `#821515` → `#681111`, stitching inset 8 pt, tray height 106 pt, round button 96 pt.
  - **Scrolling:** the tray scrolls sideways together with its leather (`TrayScroll`), and vertical drags go through `ScrollPanProbe` (brief K1, K2).
  - **Haptic:** a light haptic when a tool is picked.
- MODIFIED Editor header:
  - Shows the back button, title, collaborator presence stack, and on the right:
    - Undo (only while Scissors or Pencil is on);
    - an `ellipsis.circle` menu with Background, Add Page, Move Left / Right, Delete Page.
  - "Done" is removed. Pages are always editable and save automatically.
- ADDED Page gestures:
  - Double tap a photo → full-screen photo.
  - Swipe left / right on an empty area → change page. This is off while Pencil, Washi or Scissors is on.
- MODIFIED Page size: 3:4, width = min(screen width − 16, (height − 220 − 36) × 3/4), so the open trays never cover it. `.ignoresSafeArea(.keyboard)`.
- REMOVED `ScrapbookPhotoPickerView` (Photos tray replaces it) and the bottom `StickerPanel` (the sticker sheet now opens on the page).

### Tools
- MODIFIED **Scissors:** moves to the main tray (leftmost). Tapping it turns cut mode on or off, and the scissors lift while it's on. Cut behavior is unchanged.
- MODIFIED **Pencil:** the tray replaces the system `PKToolPicker`. The second tray holds:
  - **Tools:** Pen (`.pen`), Brush (`.watercolor`), Marker (`.marker`), Crayon (`.crayon`), Fountain pen (`.fountainPen`), **Eraser `PKEraserTool(.bitmap)`**, and Pick color (system color picker).
  - **Eraser:** erases only the part the finger passes over, not whole strokes. There is no vector eraser.
  - **Pen size panel:** tapping the active tool again opens 5 sizes (× 0.35 / 0.65 / 1 / 1.43 / 2.04 of the base width) and an opacity slider (10–100%). The panel closes when drawing starts.
  - **Color:** applies to every ink tool, not the eraser. It starts black.
  - **Input:** finger and Apple Pencil (`.anyInput`).
  - **Dark mode:** the canvas uses the light style always (K5).
  - **Undo:** undoes the last stroke of the active layer. There is no redo.
  - **No reed pen.**
- ADDED **Drawing layers:** a drawing is a page item (`ScrapbookItem.drawingData`) ordered by `zIndex` with the other items.
  - **Where strokes go:** opening Pencil draws into the frontmost item if it's a drawing layer; otherwise a new layer is created in front.
  - **Editing:** the eraser and undo only touch the active layer.
  - **Shape:** a layer always covers the whole page and can't be moved. Its empty parts let touches through.
  - **Empty layers:** removed when Pencil closes.
  - **Rendering:** only the active layer is a `PKCanvasView`; the others are cached still images.
  - **Saving:** layers save 0.5 s after each stroke.
- MODIFIED **Stickers:** the second tray shows two sheets, Travel (existing) and Fun (27 stickers).
  - **Opening:** tapping a sheet opens it in the middle of the page (83% of the page width) and dims the page.
  - **Placing:** the peel–drag–stick animation stays. Dropping on the sheet returns the sticker; dropping outside the sheet sticks it. The sheet fades to 40% while a sticker is dragged off it.
  - **Stock rules:** single use per sheet per scrapbook, "Take a New Sheet" when empty. Unchanged.
- MODIFIED **Photos:** the second tray shows this roll's photos as small polaroids keeping each photo's own ratio (long side 52 pt, white frame, ±6°, newest on the left, Live badge).
  - **Tap:** adds the photo with the existing placement rule.
  - **Drag up onto the page:** drops it where the finger lifts.
  - **Empty tray:** shows "Photos from this roll appear here." (existing text).
- ADDED **Washi:** 4 rolls.
  - **Pulling:** tap a roll, put a finger on the page and pull. The tape comes out in a straight line with a torn start, a light haptic every ±20 pt, and the roll spinning.
  - **Tearing:** lifting the finger tears the tape (jagged end, medium haptic) and the piece becomes an item in front.
  - **Tape look:** width 16% of the page, minimum length 10% (shorter pulls are cancelled), opacity 0.88. The pattern is drawn in code, and the tear shape comes from `tearSeed`.
  - **After placing:** pieces can be moved, rotated, pinched and removed.
- ADDED **Letters:** A–Z and 0–9 cut-out letters, reusable.
  - **Tap:** places a letter at x 12%, y 35%, rotated ±8°. Taps within 3 s line up to the right and wrap to the next line.
  - **Drag up:** drops it where the finger lifts.
  - **Size:** height 12% of the page width.
- ADDED **Text:** tapping Text opens a typing screen over the dimmed page.
  - **Options:** 7 colors (black, white, tray red, blue, green, yellow, pink) and Done.
  - **Placing:** Done or a tap outside places the text at center, y 40%. Empty text isn't added, and clearing an existing text removes it.
  - **Editing again:** double tap, or long-press → "Edit Text".
  - **Font:** system serif semibold. Font size = `width` × page width (start 0.08), wrapping at 80% of the page width.
- MODIFIED **Long-press menu:** adds "Edit Text" for text items.
- ADDED **Corner handle:** a selected item (not drawing layers) shows a round handle on its bottom-right corner. Dragging it away from / toward the item's center resizes it, and around the center rotates it, with one finger. Pinch still works. Small items like letters are hard to pinch.

### Hints
- ADDED The washi hint "Put your finger on the page and pull to stick washi tape", the existing scissors hint ("Drag across a photo to cut. Long press to move.") and the pencil hint ("Draw with your finger or Apple Pencil." on iPad, "Draw with your finger." on iPhone) show **only once per scrapbook**: the first time that tool is turned on in that scrapbook [Draft text].

### Limits and text
- MODIFIED `ScrapbookPage.maxItems` 20 → 40. Drawing layers count toward it.
- MODIFIED Full page shows the existing toast "This page is full". The item isn't added, and a washi pull is cancelled.

### Data (lightweight migration, all fields optional)
- MODIFIED `ScrapbookItem` new fields:
  - `drawingData: Data?`, `letterID: String?`, `text: String?`, `textColor: String?`;
  - `washiID: String?`, `washiLength: Double?`, `tearSeed: Int?`.
- MODIFIED The item kind comes from the filled field: drawing → sticker → letter → text → washi → photo.
- MODIFIED Width limits are per kind (`widthRange`): letters down to 0.04, washi up to 1.6, photos and stickers 0.15–1.0.
- MODIFIED `ScrapbookPage.drawingData` is no longer drawn. On first open, an existing page drawing moves into one drawing layer at the back.
  - The drawing space stays **600 × 800** (`ScrapbookPage.canvasSize`, not the POC's 750 × 1000), so old drawings don't shift.
  - The POC widths are scaled by 600 / 750.
- MODIFIED `Scrapbook` stores whether the washi, scissors and pencil hints were already shown.
- MODIFIED The cover draws every item of the first page, drawing layers included.

### Collaboration (local only, for the Supabase follow-up)
- New items stay **on this device only** in this change:
  - letters, text, washi, drawing layers;
  - sticker items from the Fun sheet.

  They aren't broadcast and aren't applied from friends.
- Because drawings move from the page into layer items, `drawing_updated` (page drawing) is **no longer sent**: pencil drawings become local only. Photos, Travel stickers, moves, cuts, backgrounds and pages keep syncing as they do now (change 042).
- To do in a later change (a teammate implements the Supabase side):
  - extend `item_placed` / `item_transformed` / `item_removed` with `letterID`, `text`, `textColor`, `washiID`, `washiLength`, `tearSeed`, `drawingData`, and the Fun sticker ids;
  - send and apply drawing layers per item instead of per page.

  This is recorded as [Open] under Scrapbook sync in tech.md.

## Tasks
- [x] Copy POC assets `Tray/`, `Letters/`, `Stickers/` (Fun sheet and stickers, without `sticker-sheet-fun-full`) and `scissors` into `Assets.xcassets`. Skip any that already exist identically.
- [x] Data: add the new `ScrapbookItem` fields, `kind`, `widthRange`, `maxItems = 40`, and the hint flags on `Scrapbook`. Move old page drawings into a back drawing layer. Test the migration with an existing scrapbook.
- [x] Port the tray:
  - `ScrapbookTool`, `ToolTray`, `TrayScroll`, `ScrollPanProbe`, `SubTrays`, `TrayDragController`;
  - rename types that clash with the app;
  - put the files under `Features/Scrapbook/Components/`.
- [x] Port Pencil (`PencilController`, `DrawingLayerView`, `PencilTray`):
  - bitmap eraser;
  - pen size panel;
  - color;
  - drawing layers on the 600 × 800 space;
  - replace `PencilCanvasView` and the system tool picker.
- [x] Port Washi (`WashiCatalog`, `WashiTapeView`, `WashiPullOverlay`), Letters (`LetterCatalog`), Text (`TextItemColor`, `TextItemEditor`).
- [x] Stickers: Fun set in `StickerCatalog`; `StickerSheetOverlay` on the page; `StickerDragController` drop-off computed from the sheet frame.
- [x] Photos tray with tap and drag; remove `ScrapbookPhotoPickerView` and `StickerPanel`.
- [x] Editor:
  - header with Undo and the `ellipsis.circle` menu; remove "Done";
  - double tap for full screen; swipe to change page;
  - the new page size;
  - once-per-scrapbook washi, scissors and pencil hints;
  - ViewModel logic only (no logic in Views).
- [x] Keep the existing realtime sync working for photos, Travel stickers, moves, cuts, backgrounds and pages. New kinds are not broadcast.
- [x] Unit tests:
  - item kind and width ranges;
  - migration of the page drawing;
  - drawing layer rule (reuse the frontmost layer or create a new one; empty layers removed);
  - 40-item limit;
  - letter line-up and wrap;
  - washi minimum length;
  - hints shown once per scrapbook;
  - text add, edit and clear.
- [x] Build and run all tests on the simulator.

## Out of scope
- Supabase Realtime sync for letters, text, washi, drawing layers and Fun stickers (later change, teammate)
- Cutting washi or letters with the scissors; font choices for text
- Redo for the pencil
- Re-exporting assets from Figma
- Reed pen; PaperKit markup
- Changing the cut, Live Photo loop, or sticker stock rules
