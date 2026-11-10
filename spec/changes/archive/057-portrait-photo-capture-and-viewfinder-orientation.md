# 057: Portrait Photo Capture and Viewfinder Orientation
Status: Done

## Why
When taking a picture with the phone held upright in portrait, the photo is currently saved as landscape. This happens because `CameraMotionService` and `RollCameraOrientation` only detect landscape left and right, leaving capture connections locked in landscape. When opening the scrapbook, these shots appear in an unexpected horizontal orientation.

Even though the analog camera UI element remains landscape, captured photos taken in portrait orientation must be saved upright in portrait. Viewfinder-exclusive labels and buttons must also dynamically rotate to portrait: the participant count badge rotates to portrait and sits at the physical top-right of the viewfinder, and the action/debug buttons (host `END ROLL` and `DEBUG: LAST SHOT`) rotate to portrait and position at the physical bottom-left of the viewfinder.

## Touches
tech.md (Camera, orientation tracking, photo capture), ui.md (Capture session viewfinder HUD)

## Changes
- MODIFIED `ScrapIt/Core/Models/RollCameraOrientation.swift`:
  - Extend orientation resolution to recognize upright portrait alongside landscape left and landscape right.
  - Add capture angle calculation ensuring photos captured in portrait upright are saved with upright portrait dimensions/orientation.
  - Add orientation helpers for viewfinder element rotation angles and layout positions.
- MODIFIED `ScrapIt/Core/Services/CameraMotionService.swift`:
  - Update CoreMotion gravity checks and UIDevice notifications to report upright portrait orientation in addition to landscape sides.
- MODIFIED `ScrapIt/Core/Services/CameraEngine.swift` / `ScrapIt/Core/Services/CameraController.swift`:
  - Set photo output rotation angle to upright portrait during portrait captures, while keeping live preview filled in landscape within the viewfinder.
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Dynamically rotate the participant indicator to portrait and place it at the physical top-right of the viewfinder when held in portrait, preserving top-left placement in landscape.
  - Dynamically rotate host `END ROLL` and `#if DEBUG` buttons to portrait and place them at the physical bottom-left of the viewfinder according to orientation.

## Tasks
- [x] Update `RollCameraOrientation` to identify portrait upright orientation and calculate portrait photo capture rotation.
- [x] Update `CameraMotionService` to notify orientation changes for portrait upright and landscape sides.
- [x] Update `CameraEngine` and `CameraController` to save portrait photos with upright portrait orientation while keeping viewfinder preview filled in landscape.
- [x] Update `CaptureSessionView` viewfinder HUD to rotate participant count indicator and anchor it at the physical top-right in portrait.
- [x] Update `CaptureSessionView` viewfinder HUD to rotate host `END ROLL` and debug buttons and anchor them at the physical bottom-left according to orientation.
- [x] Add unit tests for portrait orientation calculations and capture rotation angles.
- [x] Run test suite to verify no regressions.

## Out of scope
- Portrait analog camera body UI (body frame, shutter button, top plate, bottom controls bar stay in landscape).
- Portrait upside down orientation.
- Rotating the live preview stream inside the viewfinder (preview stays filled in landscape).
- Controls outside the viewfinder (shutter button, flash/live/flip bar, shots dial, top plate buttons do not rotate).
- Non-camera screens.
