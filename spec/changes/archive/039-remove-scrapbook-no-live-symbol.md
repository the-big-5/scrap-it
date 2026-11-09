# 039: Remove No Live Symbol When Motion Disabled in Scrapbook
Status: Done

## Why
When a Live Photo is placed on a scrapbook page and motion is turned off (via the item context menu or system settings), a `livephoto.slash` icon badge currently overlays the top-right corner of the photo. The canvas should display the still photo cleanly without any disabled-motion symbol overlay.

## Touches
ui.md (Scrapbook Editor items)

## Changes
- MODIFIED `ScrapIt/Core/DesignSystem/Scrapbook/ScrapbookItemView.swift`:
  - Remove `.overlay(alignment: .topTrailing)` that displays `Image(systemName: "livephoto.slash")` when `isEditable && isLive && !item.loopEnabled`.
  - Preserve context menu actions for toggling motion ("Turn Off Motion" / "Turn On Motion").

## Tasks
- [x] Remove `livephoto.slash` top-trailing overlay from `ScrapbookItemView.swift`
- [x] Verify Live Photo items with `loopEnabled == false` display without any overlay badge
- [x] Verify item context menu retains motion toggle functionality
- [x] Run existing test suite to ensure zero regressions

## Out of scope
- Live Photo badge indicator in `ScrapbookPhotoPickerView` thumbnail grid
- Live Photo badges in camera capture or roll flow
- Modifying `ScrapbookItem.loopEnabled` data model or `LivePlaybackCoordinator`
