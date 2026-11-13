# 128: Playful Bookshelf Interaction & 3D Book-Open Animation

Status: Done

## Why
- Opening a saved scrapbook from the Profile bookshelf currently feels flat: tapping a spine immediately triggers a standard navigation push onto `ScrapbookCoverScreen` over the cutting mat, and opening a closed cover cross-fades by opacity into `ScrapbookBookView`.
- Based on Figma (`1300:36434`, `1573:27257`, `1573:28563`, `1573:29417`, `1573:30280`, `1573:31127`) and the animation reference (`image/ScreenRecording_11-13-2026 16-39-07_1.mp4`), the bookshelf should feel tactile and alive: spines react physically under touch/drag, tapping a book pulls it smoothly off the shelf over a blurred shelf backdrop and hinges the front cover open in 3D directly into a readable two-page spread, and `ScrapbookCoverScreen` should reuse the same 3D cover-hinge open feel.

## Touches
flows.md (F4 Profile bookshelf, F5 step 5), ui.md (Screen: Profile tab, Screen: Scrapbook), tech.md (Code structure)

## Changes
- ADDED `ScrapIt/ScrapIt/Features/Profile/Components/BookshelfReaderOverlay.swift` (or equivalent overlay + shared 3D cover-hinge component in `ScrapIt/ScrapIt/Core/DesignSystem/Scrapbook/`):
  - Full-screen overlay displayed directly above `ProfileView` when a scrapbook is selected from the bookshelf, keeping the bookshelf rendered underneath with an animated blur backdrop (`Kraft.lightActive` shelf softly blurred).
  - **2-Phase Choreographed Pull-Out + 3D Hinge Open** (matching `ScreenRecording_11-13-2026 16-39-07_1.mp4` and Figma `1573:27257` → `1573:28563`):
    1. *Pull-out to front cover*: Tapped spine lifts and springs toward screen center (`matchedGeometryEffect` / anchor transition), expanding into the front cover (`BookCoverArt` + front `ScrapbookPageView` decorations, `340 × 468` baseline scaled proportionally on iPhone and generously on iPad Portrait & Landscape).
    2. *3D cover-hinge open*: Immediately hinges the front cover open around its leading spine edge (`rotation3DEffect` `0° → -180°` with perspective and fold shading) directly into the centered two-page spread (`357.6 × 246.1` baseline scaled for iPhone and iPad), paired with haptic feedback.
  - **Interactive 3D Page Turning & Read-Only Zoom**:
    - Horizontal drag turns spreads in 3D around the center spine (reusing realistic leaf rotation + shadow darkening; bounded at spread `0` and last spread).
    - Tapping an open spread opens read-only page inspection (`ScrapbookEditorView` / read-only spread zoom with two-finger pinch zoom and Live Photo playback, no editing tools).
    - Tapping `✕` folds the spread back closed and tucks the book smoothly back onto its shelf slot while unblurring the shelf.
    - Respects `accessibilityReduceMotion` (uses gentle opacity/scale cross-fade without spring overshoot or 3D hinge swing).
  - **Top Bar & Popovers** (Figma `1573:28530`–`1573:28540`, `1573:29417`, `1573:30280`, `1573:31127`):
    - Leading: circular `✕` button (returns book to shelf).
    - Center: scrapbook title + `"Private"` subtitle.
    - Trailing:
      - Collaborators button (`ScrapbookPeople`) → frosted popover listing the scrapbook's members (avatar/initial circle + display name).
      - `"⋯"` menu → `"Save as Video"` (disabled placeholder), `"Make Private"` / `"Make Public"` (disabled placeholder), and `"Delete Scrapbook"` (destructive → triggers `"Delete this scrapbook?"` / `"Its photos on this phone are deleted too."` confirmation, dismissing overlay and reloading shelf on confirm).
- MODIFIED `ScrapIt/ScrapIt/Features/Profile/Components/BookshelfRowView.swift` & `ProfileView.swift`:
  - Add tactile press lift + subtle scale/shadow + light haptic when pressing a spine.
  - Support horizontal finger-drag ripple across shelf spines (spines lift/tilt smoothly by proximity like piano keys/books on a shelf and settle back with spring physics on release; tapping selects the book without conflicting with vertical scroll).
  - Present `BookshelfReaderOverlay` cleanly above `ProfileView` (covering the tab bar / safe area with the blurred shelf backdrop) instead of immediately pushing `AppRoute.scrapbook` on spine tap.
- MODIFIED `ScrapIt/ScrapIt/Features/Profile/ProfileViewModel.swift`:
  - Hold `openedScrapbook: Scrapbook?` (or selected reader state) + collaborator rows helper for the overlay while keeping `requestDelete` / `confirmDelete` synced with the shelf and supporting read-only spread zoom navigation when tapping an open spread.
- MODIFIED `ScrapIt/ScrapIt/Features/Scrapbook/ScrapbookEditorView.swift`, `ScrapbookCoverScreen.swift`, & `ScrapbookBookView.swift`:
  - Extract/share the 3D cover-hinge open/close transition so tapping a closed cover on `ScrapbookCoverScreen` (`openReadOnlyBook()`) hinges the cover open into `ScrapbookBookView` in 3D (and `closeReadOnlyBook()` folds back closed) instead of fading via `.opacity`.

## Tasks
- [x] Add tactile spine press lift, spring settle, haptic feedback, and finger-drag proximity ripple across shelves in `BookshelfRowView` (respecting `accessibilityReduceMotion` and vertical `ScrollView` scrolling).
- [x] Build shared 3D cover-hinge open/close book transition component (`BookCoverHingeTransition` or equivalent) supporting cover art + front page decorations hinging around the spine into a two-page spread.
- [x] Build `BookshelfReaderOverlay` over `ProfileView` with blurred bookshelf backdrop, 2-phase spine pull-out → 3D cover-hinge open, 3D page-turning spreads, read-only spread zoom tap-through, and reverse close-to-shelf dismissal (adaptive for iPhone & iPad Portrait/Landscape).
- [x] Implement the overlay top bar (`✕`, title + `"Private"` subtitle, Collaborators popover matching Figma `1573:30280`, and `"⋯"` menu with disabled `"Save as Video"` / `"Make Private"` / `"Make Public"` placeholders and wired `"Delete Scrapbook"` confirmation).
- [x] Reuse the 3D cover-hinge open/close transition for `ScrapbookCoverScreen` ↔ `ScrapbookBookView` when opening/closing read-only books in `ScrapbookEditorView`.
- [x] Add unit tests (where logic is extracted, e.g., shelf ripple physics/offset calculation and reader/collaborator view-model state) and build/run tests cleanly.

## Out of scope
- Implementing backend/UI `"Save as Video"` export or toggling real CloudKit `"Make Public"` / `"Make Private"` visibility (kept as disabled placeholders in `"⋯"`).
- Changing `ScrapbookEditorView` tool trays, PencilKit drawing, or collaborative live editing flows.
