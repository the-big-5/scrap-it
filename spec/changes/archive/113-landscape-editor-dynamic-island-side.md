# 113: Landscape editor follows the Dynamic Island side; pencil size panel above the home indicator
Status: Done

## Why
- Scrapbook edit view in landscape (Figma 1563:31649, 1563:30868): the buttons belong on the Dynamic Island side and the tool tray on the other side. The code picks the side from the safe area (`insets.leading >= insets.trailing`), but on Dynamic Island iPhones the landscape safe area is the same on both sides, so the buttons always end up on the left. Turned the other way (Dynamic Island on the right), the tray, which runs to the screen edge, sits under the Dynamic Island.
- The pencil size / opacity panel in landscape sits 12 pt above the bottom edge, right next to the home indicator, where a swipe leaves the app.

## Touches
ui.md (Scrapbook: edit view landscape, pencil)

## Changes
- MODIFIED Edit view landscape (change 025): the side follows how the phone is turned. Dynamic Island on the left (Figma 1563:31649): buttons on the left, tray on the right. Dynamic Island on the right (Figma 1563:30868): buttons on the right, tray on the left. It switches when the phone is turned over.
- MODIFIED Pencil size / opacity panel in landscape (change 022): stays at the bottom corner beside the tray, raised to about 60 pt above the bottom edge of the screen (was about 33 pt), clear of the home indicator.

## Tasks
- [x] Pick the landscape side from the screen's orientation (landscape left / right), not the safe area
- [x] Raise the landscape pencil size panel to about 60 pt above the bottom edge of the screen
- [x] Build and run all tests (351 passed); test on device in both landscape directions

## Out of scope
- Portrait layout, the pencil panel in portrait
- Button, tray and panel designs; anything else in landscape
