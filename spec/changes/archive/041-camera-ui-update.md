# 041: Camera UI Update
Status: Done

## Why
Synchronize `Features/Roll` (`CaptureSessionView`) with the latest Mid-Fi design in Figma (`ujlkuWobqxyvtQwh5plhGF`):
- Back Camera: Node `1302:47935`
- Front Camera: Node `1300:33796`

The new layout streamlines the capture interface:
1. Replaces the legacy digital box shots counter (`00 /36`) and optical viewfinder housing with a dedicated circular analog shots-left dial element located in the lower-right deck beside the shutter well.
2. Relocates the participant presence counter to the top-left of the camera preview viewfinder (replacing the redundant `LIVE` badge).
3. Evenly distributes the capture controls (Flash, LIVE, and Flip) across the bottom shelf under the viewfinder.
4. Condenses the top deck: adds a circular Back button on the leading edge (returning to Homepage), an Information button on the trailing edge (showing the roll invite code / share sheet), and positions the knurled zoom wheel exclusively for the back camera (front camera omits zoom control entirely).
5. Removes the legacy rule-of-thirds grid overlay and button entirely.
6. Preserves the host "End Roll" control and debug buttons.

## Touches
ui.md (Capture session screen), flows.md (F2 Capture Flow)

## Changes
- ADDED `ScrapIt/Features/Roll/Components/ShotsLeftDialView.swift`:
  - Circular analog dial displaying remaining shots count with rotating mechanical drum aesthetic matching Figma nodes `1302:47951` / `1300:33812`.
- MODIFIED `ScrapIt/Features/Roll/RollFlowViewModel.swift`:
  - Add `shotsRemaining: Int` computed property (`max(0, (activeSession?.rollSize ?? 36) - (activeSession?.slotsUsed ?? 0))`).
  - Add `returnToHomepage()` method to pop navigation stack to root while preserving active roll state.
- REMOVED `ScrapIt/Features/Roll/Components/CameraGridOverlay.swift`:
  - Remove grid overlay component as grid feature is deprecated.
- MODIFIED `ScrapIt/Core/Services/CameraController.swift`:
  - Deprecate/remove `isGridVisible` state.
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Update top deck:
    - Add leading circular Back button returning to Homepage via `flowViewModel.returnToHomepage()`.
    - Knurled zoom wheel with `ZOOM 1.0x` label shown only when `!camera.isUsingFrontCamera`.
    - Add trailing circular Info button presenting `flowViewModel.isInviteSheetPresented`.
  - Update viewfinder preview HUD:
    - Move participant count badge (`person.2.fill` + count, plus queued count if offline) to top-left of the viewfinder screen.
    - Remove top-left `LIVE` badge from the viewfinder HUD.
    - Remove grid overlay integration.
    - Preserve host "END ROLL" button and debug actions (`DEBUG: LAST SHOT`).
  - Update lower body controls:
    - Position Flash (`bolt.slash`/`bolt.fill` + "FLASH"), LIVE (`livephoto` + "LIVE"), and Flip (`arrow.trianglehead.2.clockwise.rotate.90` + "FLIP") buttons in a horizontal row below the viewfinder with equal spacing.
    - Integrate `ShotsLeftDialView` in the lower right deck next to the shutter well.
    - Embed circular metallic shutter button with press animation inside recessed shutter well.
    - Remove legacy optical viewfinder housing and right-column grid button.

## Tasks
- [x] Remove `CameraGridOverlay.swift` and eliminate `isGridVisible` from `CameraController.swift`
- [x] Add `shotsRemaining` and `returnToHomepage()` to `RollFlowViewModel.swift`
- [x] Create `ShotsLeftDialView.swift` implementing the circular analog shots-left dial
- [x] Update `CaptureSessionView.swift` top plate (Back button, conditional zoom wheel for back camera only, Info button)
- [x] Update `CaptureSessionView.swift` viewfinder HUD (move participant count to top-left, remove grid, keep host/debug actions)
- [x] Update `CaptureSessionView.swift` bottom controls (equally spaced Flash, LIVE, and Flip buttons)
- [x] Update `CaptureSessionView.swift` body layout with circular analog shots-left dial and shutter well
- [x] Run test suite to verify no regressions in capture flow or navigation

## Out of scope
- Changing camera capture pipeline, AVFoundation engine, or lens switching logic
- Modifying `KnurledZoomWheelView` internal gesture or haptic mechanics
- Modifying scrapbook editor, photo cards, or post-capture review flows
- CloudKit or Supabase roll sync transport changes
