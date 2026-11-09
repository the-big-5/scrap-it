# 035: Remove Viewfinder Live and Zoom Labels
Status: Done

## Why
In `Features/Roll` (`CaptureSessionView`), the camera preview viewfinder displays HUD badges for "LIVE" on the top left and current zoom factor (e.g., "1.0x") on the bottom right. These labels duplicate controls already clearly visible outside the viewfinder on the camera body (the top deck LIVE toggle pill and the knurled zoom wheel), unnecessarily cluttering the preview frame.

Removing both badges cleans up the viewfinder while keeping camera functionality, external controls, and haptics intact.

## Touches
ui.md (Capture session camera body and viewfinder HUD)

## Changes
- REMOVED from `CaptureSessionView`:
  - Viewfinder top-left "LIVE" HUD badge overlay.
  - Viewfinder bottom-right zoom factor HUD badge overlay.
- RETAINED:
  - Top deck LIVE toggle button.
  - Knurled zoom wheel controls and haptic behavior.
  - Viewfinder top-right participant count and offline queue badge.
  - Viewfinder bottom-left "END ROLL" and "DEBUG: LAST SHOT" buttons.

## Tasks
- [x] Remove the top-left LIVE HUD badge overlay from `CaptureSessionView`
- [x] Remove the bottom-right zoom factor HUD badge overlay from `CaptureSessionView`
- [x] Verify viewfinder layout and ensure build and test suite pass without regressions

## Out of scope
- Modifying top deck LIVE toggle button appearance or adding recording tint
- Moving numerical zoom factor readout next to knurled wheel
- Modifying `KnurledZoomWheelView` or `ZoomWheelModel`
- Modifying viewfinder participant count, offline queue status, or host/debug buttons
