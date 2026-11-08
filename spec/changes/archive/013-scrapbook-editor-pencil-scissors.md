# 013: Scrapbook editor (pages, Live Photos, stickers, pencil, scissors) and scrapbooks on Profile
Status: Done

## Why
After a roll ends the user only sees a basic photo grid with captions. While the design team works on the real flow, the user wants a temporary flow: end roll → straight into a scrapbook editor where they choose photos from the roll (Live Photos included) and decorate pages, ported from the camera POC (`TBF/POC/Camera/FilterCam/Scrapbook`). Scrapbooks are reached from the Profile tab.

## Touches
flows.md (F3 step 10, F4 Profile shelf, F5 Scrapbook), ui.md (Profile tab, Scrapbook screen), tech.md (Data models, Code structure, PencilKit)

## Changes
### Flow
- MODIFIED F3 / F5: when a roll ends, the app goes straight to that roll's scrapbook, in **edit mode**. The scrapbook starts with one empty page; the user adds photos themselves
- Scrapbooks are only created from ended rolls (no "+ new scrapbook")
- A separate view mode (swipe pages, Live Photos play, no tools) comes later with the design team's flow [Open]
- REMOVED: the basic grid screen (`ScrapbookGridView`, `ScrapbookPhotoCard`) and the caption UI (`ScrapPhoto.caption` stays in the model and the encrypted payload, just not shown)

### Scrapbook editor (ported from the POC, temporary; may change with the design)
- Multiple pages (3:4): add, delete, move left / right, previous / next page, "n / N" indicator
- Photos: picker shows **only the photos of this scrapbook's roll** (own + friends', Live Photos included, marked LIVE). Max 20 items per page (POC)
- Items: drag, pinch to resize, rotate, bring to front, delete; white photo frame as in the POC
- Live Photos loop on the page (muted), per-photo motion on/off, paused in Low Power Mode and when the screen is not visible (POC rules)
- Background picker (POC list: colors + lined / grid / dotted paper) — may change later
- Stickers: POC "Travel" sticker sheet (drag from the panel onto the page, each sticker used once, "new sheet") with the POC assets — may change later
- Scissors: same as the POC (drag to cut a photo, long-press to move, two fingers to pinch / rotate, undo while the scrapbook is open, scissors asset and haptics) — may change later
- Pencil (new, PencilKit): one drawing layer per page, on top of photos and stickers. System tool picker with every tool available on iOS 18 (pen, pencil, marker, monoline, fountain pen, watercolor, crayon, eraser, lasso, ruler, colors). Reed pen is excluded (iOS 26). Drawing with a finger allowed (iPhones have no Apple Pencil). While the pencil is on, photos cannot be moved
- No markup (PaperKit needs iOS 26)

### Profile
- Profile tab shows the user's scrapbooks as a 2-column cover grid like the POC (first page as a small still cover, title, page count), newest first. Tap → editor. Not the Figma book / shelf assets (Figma 1109:4648 used as reference only)
- Empty state: short text that scrapbooks appear after a roll ends [Draft]
- Long-press a cover → "Delete" → confirmation ("Delete this scrapbook?", photos on this phone are deleted too; Delete / Cancel), kept for now (user decision) [Draft]
- Temporary "Sign Out" button stays

### Delete scrapbook (proposal, user asked for delete "so it doesn't fill the database")
- Deletes on this device: the scrapbook, its pages / items / drawings, its photos and the roll's local `CaptureSession`
- The roll's session ID is remembered locally so the background restore (012) does not bring it back on this device
- Cloud data is kept (friends still need their copies). On a new phone the scrapbook would be restored again [Open]

### Storage
- Pages, items (position, size, rotation, z-order, cut shape, motion on/off), sticker sheets, background and the PencilKit drawing are stored **only on this device** (local `Rolls` store). Not restored on a new phone and not shared with roll friends. Collaboration on scrapbooks comes later [Open]
- New SwiftData models (local store): `ScrapbookPage`, `ScrapbookItem` (refers to `ScrapPhoto.id` or a sticker id), `StickerSheet`; `Scrapbook` gets pages and sticker sheets. Models follow the CloudKit-compatible rules (defaults, no `.unique`, optional relationships) so they could sync later

### Architecture
- The code does not need to match the POC structure; it must follow this repo's rules (user decision): no logic in Views (state, gestures' results, saving, cut / sticker / page rules live in ViewModels or Core), no `modelContext` in Views, ViewModels without SwiftUI, Views only render and forward actions. Routes go through the shell's `AppRoute` (teammate's app shell, change 009 composable shell). Only the POC's look and behavior are reused

## Tasks
- [x] Models: `ScrapbookPage`, `ScrapbookItem`, `StickerSheet`, `PageBackground`, `StickerCatalog`; add to the `Rolls` schema
- [x] Assets: copy POC sticker images, sticker sheet and scissors image into `Assets.xcassets/Scrapbook/`
- [x] Editor screen (edit mode only): pages, item manipulation, page menu, background picker, photo picker limited to the roll's photos
- [x] Live Photo looping on the page (`LoopingVideoView` from local movie data) with the POC playback rules
- [x] Stickers: panel, drag-to-page, used stickers, new sheet
- [x] Scissors tool, cut geometry, undo (POC)
- [x] Pencil: PencilKit canvas per page, tool picker without reed pen, finger drawing, saved per page
- [x] End roll → editor of that roll's scrapbook (replaces the grid route)
- [x] Profile: cover grid, empty state, long-press delete with confirmation, Sign Out kept
- [x] Delete scrapbook + restore skip list
- [x] Remove `ScrapbookGridView`, `ScrapbookPhotoCard` and the caption UI
- [x] Tests (Swift Testing): page add / delete / move, add photos (limit 20, only the roll's photos), item transform save, cut mask save / undo, sticker used once, drawing saved per page, delete scrapbook removes local data and restore skips it, end roll navigates to the editor
- [x] Build and run all tests on Simulator
- [x] Manual check on iPhone: end a roll → editor; add photos incl. Live (loops); background; sticker; cut; draw with finger (no reed pen); leave and reopen from Profile, everything is still there; delete from Profile; relaunch, it does not come back — user confirmed ("sudah") before the merge

## Out of scope
- View mode / final scrapbook flow and book / shelf design (waiting for the design team)
- Markup (PaperKit), reed pen (iOS 26)
- Renaming scrapbooks, creating empty scrapbooks
- Syncing / sharing scrapbook layouts (collaboration), restoring layouts on a new phone
- Deleting cloud data (public shots, rooms)
- Full-screen photo viewer (POC view mode)

## Open
- Stickers, backgrounds and scissors behavior may change with the design
- Scrapbook collaboration rules (F5) and syncing layouts
- Deleted scrapbook returns on a new phone (cloud data kept)

## Notes
- PencilKit is available on iOS 13+, fine for the iOS 18 minimum. The tool picker on iOS 18 already has no reed pen; on iOS 26 devices the tool list is set explicitly so it stays excluded
- `ScrapPhoto.caption` is kept so older data and the encrypted payload stay compatible

## Implementation findings
- Models (local `Rolls` store): `ScrapbookPage` (order, background, `drawingData`, items), `ScrapbookItem`, `StickerSheet`; `Scrapbook.pages` / `stickerSheets` (cascade). `PageBackground`, `StickerCatalog` in `Core/Models/`
- Logic in `ScrapbookViewModel` (no SwiftUI): pages, photos (only the roll's, max 20), transform clamp / ±3° snap, z-order, motion toggle, stickers (once per sheet), cut + undo (last 20 cuts while the editor is open), drawing per page, toast / save error. `ProfileViewModel`: cover list, open, delete
- Pure helpers in `Core/Services/`: `CutGeometry` (POC), `ScrapbookItemLayout`, `ScrapbookImageLoader` (downsample + aspect ratio from the image header, since `ScrapPhoto` has no size), `LiveMovieFileCache` (movie data → file for the looping player), `LivePlaybackCoordinator` (app active, Low Power Mode), `DeletedScrapbookList` (UserDefaults; `ScrapbookArchiveSync` skips these rolls)
- Views: page / item / background / looping video / drawing image in `Core/DesignSystem/Scrapbook/` (used by the editor and the Profile covers, so no cross-feature import); editor, scissors (gesture state only), sticker panel + `StickerDragController` (animation state, presentation only), PencilKit canvas, pickers in `Features/Scrapbook/`
- Pencil: the drawing is stored in a fixed 600 × 800 space and the `PKCanvasView` is zoomed to the page width, so it lines up on every device and on covers. Tool picker built with `PKToolPicker(toolItems:)` (iOS 18): pen, pencil, marker, monoline, fountain pen, watercolor, crayon, vector + pixel eraser, lasso, ruler; no reed pen
- Navigation: `AppRoute.scrapbookGrid` renamed to `.scrapbook(UUID)`; end of roll, Workbench "latest scrapbook" and Profile covers open the editor. `ProfileView` gets the shell's navigator. Teammates' tests updated for the route name
- Removed: `ScrapbookGridView`, `ScrapbookPhotoCard`, the caption UI. `ScrapDataImageView` (unused after this change) deleted after the merge on the user's request
- Not ported from the POC: full-screen photo viewer (out of scope), light haptic on undo
- Tests: `ScrapItTests/Scrapbook/ScrapbookEditorTests.swift` (17), restore skip in `ScrapbookArchiveTests`, store split updated in `ModelContainerTests`. Full suite: 147 tests in 15 suites pass, 1 known issue (toggle contrast, 003)
- Merge: the new models are [Draft] in tech.md (user decision: the editor may still change)
