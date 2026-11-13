# 128: Spine text sizing, pencil eraser across layers, spine sticker sizing, and color picker eyedropper crash
Status: Done

## Why
- On the Edit Cover spine (`74 × 462`), plain text is constrained by the narrow `74` pt spine width before rotation, causing enlarged or longer text to wrap downward (top-to-bottom) instead of lengthening horizontally along the spine, and text max size across spine, front cover, and scrapbook pages is too small.
- Leaving and re-entering edit mode (or placing text/stickers after drawing) leaves older Pencil strokes on the spine, front cover, and scrapbook pages in separate drawing layers that the Pencil eraser can no longer erase.
- On the spine, `StickerSheetOverlay` uses front-cover dimensions (`340 × 468`), covering nearly the whole spine, while dropped stickers collapse too small relative to the narrow spine width.
- Opening the system `UIColorPickerViewController` inside SwiftUI `.sheet` + `.presentationDetents` crashes the app immediately when the user taps the eyedropper tool (Edit Cover, Spine, and Scrapbook Pencil tray).

## Touches
ui.md (Scrapbook: cover & spine, Edit Cover, edit view, Stickers, Pencil, Text)

## Changes
- MODIFIED Plain text layout and size limits (`ScrapbookItemView`, `ScrapbookItem`, `ScrapbookViewModel`):
  - Text rotated along the spine lays out up to `pageSize.height * TextItemStyle.maxWidthRatio` along its horizontal text axis before wrapping, instead of wrapping at the narrow `74` pt spine width (`pageSize.width`).
  - Raise plain text `widthRange` upper bound across all surfaces: spine `0.1...1.5` (with default `spineTextSize` raised to `0.40` so new spine text starts clearly readable), and front cover / scrapbook pages `0.03...0.6` (was `0.03...0.3`) so text can be scaled larger everywhere.
- MODIFIED Pencil drawing layer reuse (`ScrapbookViewModel.beginDrawing`):
  - When Pencil opens on a page (spine, front cover, or scrapbook spread), reuse the page's existing `.drawing` layer even if non-drawing items (text, stickers, photos, etc.) sit above it; if multiple `.drawing` layers exist on the same page, merge them into the active drawing layer so the eraser can erase any old Pencil strokes on that page while keeping text/stickers above the drawing layer after closing Pencil.
- MODIFIED Spine sticker sheet overlay and placed sticker max size (spine only — front cover and scrapbook pages unchanged):
  - Pass a scaled-down overlay sheet size (`~0.58×` of the front cover dimensions) to `StickerSheetOverlay` when `coverSide == .spine` so the sheet does not obscure the spine.
  - Raise the dropped/placed sticker width clamp (`placeSticker`) specifically for spine pages from `0.6` to `0.8` (`width / pageWidth <= 0.8`), allowing stickers dropped on the spine to land noticeably larger for comparison without changing front cover or spread pages.
- MODIFIED System color picker presentation (`BookCoverViews`, `PencilTray`):
  - Present `UIColorPickerViewController` directly via native UIKit modal presentation from the active UIKit view controller (instead of wrapping it inside SwiftUI `.sheet` + `.presentationDetents`), preventing crashes when using the color eyedropper across Edit Cover, Spine, and Scrapbook Pencil tray.

## Tasks
- [x] Fix spine text layout container before rotation so rotated spine text grows/extends in one line up to ~80% of spine length before wrapping, and raise `widthRange` max (`0.1...1.5` on spine with default `0.40`, `0.03...0.6` on front cover and scrapbook pages)
- [x] Update `beginDrawing()` to reuse (and merge if multiple) existing `.drawing` layer(s) on a page even when other items were added after drawing, across spine, front cover, and scrapbook pages
- [x] Scale `StickerSheetOverlay` container down on `.spine` (`~0.58×` front cover size) and raise spine-only placed sticker max width clamp from `0.6` to `0.8`
- [x] Replace SwiftUI `.sheet` + `.presentationDetents` wrapper around `SystemColorPicker` (`UIColorPickerViewController`) with native UIKit presentation in `BookCoverViews` and `PencilTray`
- [x] Add/update unit tests covering spine text sizing/range, drawing layer reuse/merge across non-drawing items, spine sticker max width (`0.8` vs `0.6` on cover/pages); build and run full test suite (387 tests passed, 1 pre-existing known issue in `DSContrastTests`)
- [x] Verify visually and interactively on device (spine text resizing, sticker sheet & `0.8` drop cap, eraser after re-entering, and ColorPicker eyedropper across Edit Cover / Spine / Scrapbook)

## Notes
- Keeping text max scale, sticker `0.8` spine cap, and spine `StickerSheetOverlay` ratio isolated to constants makes it straightforward to compare and fine-tune during on-device testing.
- Merging/reusing an underlying `.drawing` layer keeps `drawingLayerIDs` hiding that layer underneath `DrawingCanvasView` while Pencil is active and syncs updates via the existing `.drawingUpdated` collaboration event.

## Out of scope
- Changing sticker sheet overlay ratio or `0.6` placed sticker cap on the front cover or scrapbook spread pages
- Redesigning the pencil tool tray, brush types, or text font family
- Editing main `spec/ui.md` before this change is merged
