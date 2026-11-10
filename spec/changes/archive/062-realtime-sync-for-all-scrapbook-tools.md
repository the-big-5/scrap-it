# 062: Realtime Collaboration Sync for All Scrapbook Toolbar Tools & Slots
Status: Done

## Why
Change `022` ported the red leather tool tray (`Scissors`, `Pencil`, `Stickers`, `Photos`, `Washi`, `Letters`, `Text`), added Fun stickers, moved Pencil drawings from page-level `ScrapbookPage.drawingData` into per-layer `ScrapbookItem.drawingData`, and intentionally kept letters, text, washi, drawing layers, and Fun stickers local-only until a follow-up Supabase Realtime change. In addition, sticker sheet usage (`StickerSheet.usedStickerIDs` / `"Take a New Sheet"`), placed roll photo exclusivity (`PhotoTray`), Live Photo motion toggles (`toggleMotion`), and scissors cut undo (`undoLastCut`) currently stay personal rather than syncing across collaborators.

Updating Supabase Realtime sync so every toolbar tool, item arrangement, sticker sheet slot, and placed photo slot synchronizes live makes the collaborative scrapbook consistent for all participants.

## Touches
flows.md (F5: Scrapbook creation & collaboration), ui.md (Scrapbook editor), tech.md (Scrapbook sync / Supabase Realtime)

## Changes
- MODIFIED `ScrapIt/Core/Services/ScrapbookRealtimeService.swift` & `ScrapIt/Core/Models/ScrapbookItem.swift`:
  - Extend `ScrapbookItemPayload` with optional `Codable` fields (`nil` defaults for backward compatibility):
    - `letterID: String?`
    - `text: String?`, `textColor: String?`
    - `washiID: String?`, `washiLength: Double?`, `tearSeed: Int?`
    - `drawingData: Data?`
  - Update `ScrapbookItem.toPayload()` and `ScrapbookItem.init(payload:)` to serialize and restore all item kinds (`photo`, `sticker`, `letter`, `text`, `washi`, `drawing`).
  - Extend `ScrapbookEventType` and `ScrapbookEvent` with:
    - `loopEnabled: Bool?` on `itemTransformed` (syncs Live Photo motion toggle alongside `centerX`, `centerY`, `width`, `rotation`, `zIndex`).
    - `itemTextUpdated` (`itemID`, `text`, `textColor`) for editing existing text items.
    - `stickerSheetReset` (`stickerSetID`) for `"Take a New Sheet"`.
    - `itemCutUndone` (`restoredItem: ScrapbookItemPayload`, `removedPieceIDs: [UUID]`) for `undoLastCut()`.
    - Per-layer `drawingUpdated` (`itemID`, `zIndex`, `drawingData`).
- MODIFIED `ScrapIt/Features/Scrapbook/ScrapbookViewModel.swift`:
  - **Share all item kinds:** Update `isShared(_:)` to return `true` for `.photo`, `.sticker` (both Travel and Fun sets), `.letter`, `.text`, `.washi`, and `.drawing`.
  - **Washi & Letters:** Broadcast `.itemPlaced` in `addWashi(...)` and `addLetter(...)`; transforms and deletions sync via `commitTransform`, `finishItemManipulation`, `bringToFront`, `sendToBack`, and `removeItem`.
  - **Text:** In `commitTextEditor()`, broadcast `.itemPlaced` for new text, `.itemTextUpdated` for edited text/color, and `.itemRemoved` when cleared empty; apply `.itemTextUpdated` in `handleRemoteEvent`.
  - **Pencil drawing layers (LWW):**
    - Broadcast `.itemPlaced` when `beginDrawing()` creates a new drawing layer item.
    - Broadcast `.drawingUpdated` (`itemID`, `zIndex`, `drawingData`) when `updateActiveDrawing(_:)` saves after its 500 ms debounce and when `endDrawing()` finishes with non-empty strokes; broadcast `.itemRemoved` if `endDrawing()` deletes an empty layer.
    - Update `handleRemoteEvent(.drawingUpdated)` to update (or insert with `zIndex`) the matching `ScrapbookItem` by `itemID` (keeping `pages[event.pageIndex].drawingData` only as legacy fallback when `itemID == nil`), and bump a `remoteDrawingRevision` token if the edited layer is currently open in `DrawingCanvasView`.
  - **Live Photo motion & Scissors undo:**
    - Include `loopEnabled` in `broadcastItemTransformed(_:)` and apply it in `handleRemoteEvent(.itemTransformed)`.
    - Broadcast `.itemCutUndone` in `undoLastCut()` and handle it in `handleRemoteEvent(.itemCutUndone)` (delete `removedPieceIDs`, restore `restoredItem` mask/frame).
  - **Shared Sticker sheet slots & `"Take a New Sheet"`:**
    - In `handleRemoteEvent(.itemPlaced)` when `payload.stickerID != nil`, mark that sticker as used in the matching `StickerSheet` (`sheet(for: set).usedStickerIDs`) so collaborators cannot place the same sticker from the sheet.
    - In `takeNewStickerSheet()`, clear `usedStickerIDs` and broadcast `.stickerSheetReset` (`stickerSetID`); handle `.stickerSheetReset` remotely by clearing `usedStickerIDs` for that set.
  - **Shared single-use Photo slots in `PhotoTray`:**
    - Compute `placedPhotoIDs: Set<UUID>` across all pages of the scrapbook (`pages.flatMap(\.allItems).compactMap(\.photoID)`).
    - Filter `trayPhotos` to exclude `placedPhotoIDs` (`rollPhotos.reversed().filter { !placedPhotoIDs.contains($0.id) }`), and reject `addPhoto(_:...)` if `placedPhotoIDs.contains(id)` so collaborators cannot place the same photo twice.
    - When a photo item is removed locally or via `.itemRemoved` / `.pageDeleted` (and no remaining cut pieces reference that `photoID`), it automatically reappears in `trayPhotos`.
    - Provide `emptyPhotoTrayMessage` distinguishing `"Photos from this roll appear here."` (no roll photos) vs. `"All photos from this roll are on the scrapbook."` (all placed).
- MODIFIED `ScrapIt/Features/Scrapbook/Components/DrawingCanvasView.swift`, `ScrapIt/Features/Scrapbook/Components/SubTrays.swift`, and `ScrapIt/Features/Scrapbook/ScrapbookEditorView.swift`:
  - Pass `remoteDrawingRevision` into `DrawingCanvasView` so `updateUIView` refreshes `PKCanvasView` if a peer updates the currently active drawing layer.
  - Pass `viewModel.emptyPhotoTrayMessage` to `PhotoTray`.
- NEW `ScrapIt/Features/Scrapbook/Components/ScrapbookTrashCanView.swift` & MODIFIED `ScrapbookPageView.swift`, `ScrapbookItemView.swift`, `ScissorsToolView.swift`, `ScrapbookEditorView.swift`, `ScrapbookViewModel.swift`:
  - **Floating drag-to-trash drop target:** While dragging any movable element (photo, cut photo piece, sticker, letter, text, washi) in normal mode or long-press moving in Scissors mode, display an animated trashcan floating above the bottom tray (`ScrapbookTrashCanView`), unclipping the dragged item across the page boundary.
  - Dragging over the trashcan triggers a spring-hinged lid-open animation and scales/dims the dragged element; releasing deletes only that leftover piece when trashing a cut photo piece, while restoring removed/trashed stickers back to their exact slot on the sticker sheet (`usedStickerIDs`, synced via `.itemRemoved` / `.pageDeleted` and removing the old `"A removed sticker can't be used again."` dialog) and returning uncut photos (or photos whose cut pieces are all removed) back to their position in `PhotoTray`.
- MODIFIED `ScrapItTests/Scrapbook/ScrapbookEditorTests.swift` and `ScrapItTests/ScrapItTests.swift`:
  - Update `aPageHoldsAtMostFortyItems` (which previously reused a single `stillPhoto.id` 40 times) and `onlyPhotosAndTravelStickersAreSharedWithFriends` to reflect single-use photos and full-toolbar sharing.
  - Add unit tests verifying realtime broadcast + remote application for Washi, Letters, Text (add/edit/clear), Fun stickers, Sticker sheet slot locking + `"Take a New Sheet"`, single-use `PhotoTray` hide & return-on-delete, Pencil drawing layers (`itemID` + `drawingData`), `toggleMotion`, and `undoLastCut`.
- Specs at merge (`/merge-change`):
  - `flows.md` (F5) and `tech.md`: remove the `[Open]` note saying letters/text/washi/drawing layers/Fun stickers stay local-only, and document shared single-use photo & sticker slots and per-layer drawing sync.

## Tasks
- [x] Extend `ScrapbookItemPayload`, `ScrapbookItem` payload conversion, `ScrapbookEventType`, and `ScrapbookEvent` in `ScrapbookRealtimeService.swift` and `ScrapbookItem.swift`
- [x] Update `ScrapbookViewModel.swift` to share all item kinds (`isShared`), broadcast & apply Washi, Letters, Text (place/edit/delete), Fun stickers, Pencil drawing layers, `toggleMotion`, and `undoLastCut`
- [x] Synchronize sticker sheet slot usage (`usedStickerIDs`) + `"Take a New Sheet"` (`.stickerSheetReset`), and enforce shared single-use `PhotoTray` photo slots (hide while placed on any page, return if all items for that photo are deleted)
- [x] Update `DrawingCanvasView.swift`, `SubTrays.swift` (`PhotoTray` empty message), and `ScrapbookEditorView.swift` for remote drawing layer refresh and tray empty text
- [x] Update/add unit tests in `ScrapbookEditorTests.swift` and `ScrapItTests.swift`, and run tests on iOS Simulator to verify zero regressions
- [x] Add floating animated drag-to-trash drop target above the bottom tray for all movable elements (normal drag and Scissors long-press move), with unit tests and simulator verification

## Out of scope
- Real-time mid-stroke vector streaming or per-user dedicated drawing layers (drawing layers continue to sync after stroke completion with Last-Write-Wins)
- Real-time cursor / drag-in-progress streaming (item transforms continue to sync on gesture completion)
- Offline conflict resolution beyond Last-Write-Wins (LWW)
- Persisting or restoring scrapbook layouts via CloudKit (sync remains live via Supabase Realtime)
