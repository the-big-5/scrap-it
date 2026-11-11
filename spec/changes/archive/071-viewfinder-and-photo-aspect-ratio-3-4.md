# 071: Viewfinder and Photo Capture 3:4 / 4:3 Aspect Ratio
Status: Done

## Why
The camera viewfinder bezel is currently sized at 487 × 251 (~1.94:1 widescreen), while camera sensors capture at 4:3 and ScrapIt scrapbook pages use 3:4 portrait format. Because the preview fills the wide viewfinder frame while the capture pipeline saves the full sensor image without matching cropping, what the user frames in the viewfinder does not match what is saved. The viewfinder aspect ratio is fixed to 4:3 in the landscape camera body (333.33 × 251 pt outer bezel, 313.33 × 235 pt inner preview), which naturally orients to 3:4 portrait when the device is held upright. Both captured still photos and Live Photo movies are saved center-cropped to 4:3 in landscape and 3:4 in portrait to match the viewfinder framing exactly.

## Touches
tech.md (Camera, orientation tracking, photo capture, media compression), ui.md (Capture session camera body and viewfinder HUD)

## Changes
### 1. Viewfinder Bezel and Preview Layout
- MODIFIED `ScrapIt/Core/Models/RollCameraOrientation.swift`:
  - Define fixed `viewfinderDimensions` (outer: 333.33 × 251 pt, inner: 313.33 × 235 pt, exact 4:3 landscape ratio in camera canvas points).
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Update `screenBezelView` to use fixed 4:3 viewfinder dimensions, avoiding any dynamic frame squishing between orientations.
  - Re-align the bottom controls row (Flash, LIVE, Flip) and back button with the updated viewfinder width and horizontal center.
  - Ensure viewfinder HUD elements (participant count badge, host handover/debug buttons, iris diaphragm overlay) anchor within the fixed bezel bounds.

### 2. Live Preview Rendering
- MODIFIED `ScrapIt/Core/Services/PreviewRenderer.swift` / `ScrapIt/Features/Roll/Components/FilteredCameraPreviewView.swift`:
  - Ensure preview frame renders at exact 4:3 (landscape) or 3:4 (portrait) aspect ratio without unintended distortion or letterboxing.

### 3. Photo and Live Photo Capture Cropping
- MODIFIED `ScrapIt/Core/Services/CameraEngine.swift` / `ScrapIt/Core/Services/FilmFilterPipeline.swift`:
  - Center-crop still photo images to 4:3 in landscape and 3:4 in portrait upright orientation prior to encoding or saving, ensuring the saved JPEG matches the viewfinder frame.
- MODIFIED `ScrapIt/Core/Services/LivePhotoMovieWriter.swift`:
  - Center-crop Live Photo video frames to 4:3 in landscape and 3:4 in portrait upright orientation, preserving audio and QuickTime metadata pairing.
- MODIFIED `ScrapIt/Core/Services/CameraController.swift`:
  - Ensure placeholder frame generator `generateFilmFrameData` renders matching 4:3 landscape and 3:4 portrait dimensions.

## Tasks
- [x] Update `CaptureSessionView.swift` viewfinder bezel and preview frame to fixed 4:3 in the camera body (3:4 when rotated in portrait).
- [x] Align bottom controls shelf (Flash, LIVE, Flip) with the updated viewfinder bounds.
- [x] Update still photo processing in `CameraEngine.swift` / `FilmFilterPipeline.swift` to center-crop captured images to 4:3 in landscape and 3:4 in portrait.
- [x] Update `LivePhotoMovieWriter.swift` video export to crop video tracks to 4:3 (landscape) and 3:4 (portrait).
- [x] Update synthetic film frame generation in `CameraController.swift` to match the exact 4:3 / 3:4 bounds.
- [x] Add unit tests in `ScrapItTests` verifying:
  - 4:3 and 3:4 cropping calculations for still photos and Live Photo movies.
  - Fixed viewfinder layout bounds in camera canvas points.
- [x] Run full test suite to verify no regressions across camera, scrapbook, and reveal flows.

## Out of scope
- Changing the 874 × 402 analog camera body background image.
- Changing scrapbook 3:4 page dimensions or sticker layouts.
- Non-camera screens or workflows.
