# 036: Move Roll Shots and Zoom Labels Above Controls
Status: Done

## Why
In `CaptureSessionView`, user fingers interact with `KnurledZoomWheelView` and the camera controls in `topCameraDeck`. Having the "SHOTS" and "ZOOM <factor>x" labels placed below the controls causes fingers to obstruct the text during operation. Positioning the labels above the controls preserves visibility during capture.

## Touches
ui.md (Capture session)

## Changes
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Reorder the shots counter `VStack(spacing: 4)` in `topCameraDeck` so `Text("SHOTS")` is placed above the counter readout container.
  - Reorder the zoom wheel `VStack(spacing: 4)` in `topCameraDeck` so `Text(String(format: "ZOOM %.1fx", camera.zoomFactor))` is placed above `KnurledZoomWheelView`.

## Tasks
- [x] In `ScrapIt/Features/Roll/CaptureSessionView.swift`, move `Text("SHOTS")` above the shots counter box inside `topCameraDeck`.
- [x] In `ScrapIt/Features/Roll/CaptureSessionView.swift`, move `Text(String(format: "ZOOM %.1fx", camera.zoomFactor))` above `KnurledZoomWheelView` inside `topCameraDeck`.

## Out of scope
- Modifying `KnurledZoomWheelView` internals or gesture logic.
- Repositioning the shutter button, flash toggle, LIVE toggle, or optical viewfinder housing.
- Touching any views outside `topCameraDeck` in `CaptureSessionView.swift`.
- Updating main `spec/` files before `/merge-change 036`.
