# 107: iPad Orientation & Responsive Layout Across Scrapbook Editor, Book, and Cover

Status: Done  

## Why
Although Change `105` enabled `.all` interface orientations on iPad, `ScrapbookEditorView`, `ScrapbookBookView`, `ScrapbookCoverScreen`, and `ToolTray` remain hardcoded for iPhone geometries:
1. In **iPad Landscape** (`mode == .edit`), `ScrapbookEditorView` enters the phone-only rotated `landscapeLayout`, turning `ToolTray` `-90°` along the side edge and height-scaling the spread via `fullHeight * 3 / 4`, which clips `X` and the closed leather tool button off the bottom of iPad's `4:3` viewport. Figma `1547:29247` (`IPAD - SB`) instead keeps the top toolbar (`X` top-left; `Who's here`, `Undo`, `Redo` top-right, no Zoom button) and places an upright `402` pt floating `ToolTray` pill at the bottom-left (`leading: 21`, `bottom: 28`) over a full-screen 2-page spread.
2. In **iPad Portrait** (`mode == .edit`), `ToolTray` / `TrayScroll` stretches across the entire `1032` pt width with tools bunched on the far left and dead leather space across the right, rather than using the same compact `402` pt bottom-leading floating pill.
3. In `.book`, `.cover`, and `.editCover`, `ScrapbookEditorView` still forces `OrientationLock.set(.portrait)` when `!allowsLandscape` (snapping a Landscape iPad back to Portrait), and `ScrapbookBookView`, `ScrapbookCoverScreen`, and `editCoverView` scale strictly by `width / 402`, overflowing vertically on iPad.

## Touches
ui.md (Screen: Scrapbook), tech.md (Orientation, Code structure)

## Changes
- MODIFIED `ScrapIt/Features/Scrapbook/ScrapbookEditorView.swift`, `ToolTray.swift`, and `TrayScroll.swift`:
  - **iPad Orientation:** Keep `OrientationLock.defaultMask()` (`.all`) active on `.pad` across all scrapbook modes (`.book`, `.cover`, `.edit`, `.editCover`, regardless of `zoom`) so iPad never snaps back to Portrait, while preserving iPhone's `allowsLandscape ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait` rule and `.onDisappear { OrientationLock.resetToPortrait() }`.
  - **PencilKit-Style iPad Floating Tool Tray (`ToolTray`, `TrayScroll`):**
    - Add `EnvironmentValues.trayPillWidth` (`500` pt on iPad via `ScrapbookEditorLayout.iPadTrayPillWidth(for:)`) so both `mainTray` and every `subTray` (`PencilTray`, `StickerTray`, `PhotoTray`, `WashiTray`, `LetterTray`) share the exact same `500` pt rounded stitched leather pill width, centering narrower tool rows and clipping horizontal scrolling (`Letters`, `Photos`) inside the stitched border instead of overflowing across the screen.
    - Default the open pill to **bottom-center** (`TrayDockEdge.bottom`), allow dragging the pill (via its grabber handle or `mainTray`) to dock on **`.bottom`**, **`.leading`** (`+90°` vertical along left edge), or **`.trailing`** (`-90°` vertical along right edge), and collapse it into a bottom corner circle button (`TrayCorner.bottomLeading` / `.bottomTrailing`) when swiped toward its docked edge or dragged into a corner.
  - **Dedicated iPad Edit Layout:**
    - On **iPad Landscape** (`isPad && isLandscape`):
      - Render the 2-page spread with full-height edge-to-edge framing (`ignoresSafeArea`) fitting both `3:4` pages safely inside the viewport (`pageWidth = min(geometry.size.width / 2, fullHeight * 3 / 4)` so outer page edges never crop), centered horizontally behind the controls.
      - Render the top toolbar (`closeButton` top-leading; `whosHereButton`, `undoButton`, `redoButton` top-trailing, omitting the Zoom toggle) cleanly inside top safe area.
    - On **iPad Portrait** (`isPad && !isLandscape`):
      - Keep `portraitTopBar` (including the **Zoom toggle** `spread -> left -> right` next to `X`) and dark `Brand.primary` margin framing around the spread (fitting spread / zoomed single-page width cleanly inside `min(width, availableHeight * 3 / 4)`).
    - Preserve iPhone's existing `portraitLayout` and phone-rotated `landscapeLayout` untouched.
  - **Responsive `editCoverView`:** Compute `ScrapbookEditorLayout.coverScale(for:)` using available viewport width and vertical space (`container.height - 250`) so the front cover / spine scales generously on iPad above the bottom-centered `500` pt floating `ToolTray`.
- MODIFIED `ScrapIt/Features/Scrapbook/Components/ScrapbookBookView.swift` and `ScrapbookCoverScreen.swift`:
  - Add `bookMatScale(for:)`, `bookScale(for:)`, and `coverScale(for:)` in `ScrapbookEditorLayout` so the open book (`ScrapbookBookView`), cutting mat, `PageHintTooltip`, closed cover (`ScrapbookCoverScreen`), and bottom buttons (`Done`, `Edit Cover`, `Save Scrapbook`, `Done Editing`, `Back to Home`, max-width capped on iPad) scale prominently to fit iPad Portrait and Landscape viewports without clipping or overlapping.
- MODIFIED `ScrapItTests/Scrapbook/ScrapbookEditorTests.swift` and `ScrapItTests/Home/WorkbenchLayoutTests.swift`:
  - Add layout geometry, PencilKit dock/minimize resolution, and orientation tests verifying iPad orientation retention (`.all` across modes), iPad Landscape & Portrait spread bounds, `500` pt floating pill docking (`.bottom`, `.leading`, `.trailing`) & corner collapse, and generous `.book`/`.cover` scaling on both 10"/11" (`1024 × 768`) and 13" (`1376 × 1032`, `1032 × 1376`) iPads as well as iPhone parity.
- Specs at merge (`/merge-change`):
  - `ui.md` (`Screen: Scrapbook`): document iPad Landscape & Portrait spread editor, PencilKit-style `500` pt floating/dockable `ToolTray`, and viewport-fit iPad `.book`/`.cover`/`.editCover` scaling.
  - `tech.md` (`Orientation`): update the scrapbook spread landscape note to reflect `.all` iPad orientation across scrapbook modes alongside iPhone's spread-only landscape turn.

## Tasks
- [x] Update `ToolTray.swift` and `TrayScroll.swift` with `trayPillWidth` (`500` pt clipped pill for main + sub-trays) and PencilKit-style drag/dock/corner-minimize behavior on iPad without altering iPhone behavior
- [x] Update `ScrapbookEditorView.swift` with `.all` iPad orientation retention, iPad Landscape full-height spread + top toolbar, iPad Portrait Zoom bar + dark framing, PencilKit dockable/collapsible tray (`TrayDockEdge`, `TrayCorner`), and viewport-fit `coverScale` for `editCoverView`
- [x] Update `ScrapbookBookView.swift` and `ScrapbookCoverScreen.swift` with generous iPad Portrait & Landscape scaling (`bookScale`, `bookMatScale`, `coverScale`) so books, covers, hints, and pill buttons fill the iPad viewport cleanly without clipping or overlapping
- [x] Add unit/layout tests in `ScrapbookEditorTests.swift` and `WorkbenchLayoutTests.swift`, run `xcodebuild test` on both iPhone and iPad 13" simulators (Portrait + Landscape renders), and inspect rendered screenshots visually

## Out of scope
- Changing iPhone Portrait or iPhone sideways Landscape (`1563:30642` / `1563:30756`) scrapbook editor layouts
- Altering synced `ScrapbookItem` normalized page coordinates, `PKCanvasView` 600×800 drawing space, `StickerSheetOverlay` behavior, or Supabase Realtime event schemas
- Implementing video export or Share actions in `ScrapbookCoverScreen`
- Editing main spec files prior to `/merge-changes`
