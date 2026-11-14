# 157: Update camera UI positions (flash, LIVE, zoom text, back, End Roll)
Status: Done

## Why
- The new camera design moves a few controls: Figma 1458:25902 (portrait) and 1531:23266 (landscape, Dynamic Island on the left). Everything else on the camera body stays as it is.

## Touches
ui.md (Capture session)

## Changes
All positions are in the fixed `874 × 402` camera body (reference landscape); the controls are the existing SwiftUI ones, reused (no new assets).
- MODIFIED Flash: the well (60×120) moves from the top of the left deck to its middle, at x 64, y 138, in every orientation. Look and behavior unchanged.
- MODIFIED Back:
  - Landscape: the round well (60×60) moves from the bottom of the left deck to its top, at x 62, y 28.
  - Portrait: it stays at the bottom left of the body, which is the top left of the screen, but becomes a tab on the screen edge (60×66.7, the two corners away from the edge rounded 20, same dark gradient and inner shadow, drop shadow 0 / 4 / 5 at 25%).
  - Both: the symbol becomes `arrow.left` (25 pt regular, `#E4E4E4`); still rotates with the phone. Action unchanged.
- MODIFIED LIVE badge: always at the top left of the viewfinder as the user holds the phone, 10 pt from the edges. Landscape unchanged; in portrait it moves from the screen's top right to its top left. Toggle unchanged.
- MODIFIED Zoom: the "ZOOM 1.0×" text moves from above the wheel to below it (container at x 594, y 31, 172×83; wheel 160×60 at the top, text centered under it). In portrait the text reads along the wheel, as now. The wheel and the flip between landscape sides are unchanged.
- MODIFIED End Roll (host only, as now):
  - Size and text: a 115×72 well on the screen's edge, the two corners away from the edge rounded 20 (same red gradient, inner shadow 0 / 2 / 10 at 25%). "End Roll" 20 pt semibold, `#FEFDFB`, tracking −0.43, reading across the screen.
  - Landscape: top right of the body (x 774, y 29; the part past the edge is cut).
  - Portrait: bottom right of the screen (top right of the body, x 785, y 0, 72×115), text turned to read across the screen.
  - The confirmation pop-up and its action are unchanged.
- MODIFIED Landscape with the Dynamic Island on the right (the body shows upside down): same positions as landscape, symbols and texts turn 180° to stay readable, as now; except Back, which mirrors to the top right of the screen (body x 62, y 314) with its arrow pointing right, toward that edge.

## Tasks
- [x] Move Flash, Back, LIVE, the zoom text and End Roll in `CaptureSessionView` per orientation, reusing the existing views
- [x] Back: portrait edge tab and `arrow.left`; End Roll: 115×72 well, 20 pt text turned per orientation
- [x] Build and run all tests; check on device in portrait and both landscapes (host and participant) (408 passed, 1 known issue in `DSContrastTests`; checked on device)

## Out of scope
- The shutter, flip button, shots-left dial, viewfinder, zoom wheel behavior, camera intro and body shape
- The End Roll confirmation and Roll Complete pop-ups, and all other alerts
- Who sees End Roll (host only, unchanged)
- Editing main `spec/ui.md` before this change is merged
