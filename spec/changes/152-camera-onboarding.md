# 152: Camera onboarding tutorial
Status: Approved

## Why
- New users only read about the camera on the onboarding slides. "Let's Try It" should let them try it: a short guided tour of the real camera, then two practice shots, before signing in.

## Touches
flows.md (F1 Sign in), ui.md (Onboarding Slides, new Camera Tutorial screen, Capture session)

## Changes
- ADDED Flow: "Let's Try It" on slide 3 opens the Camera Tutorial instead of Welcome; Skip (any time) goes to Welcome / Sign in with Apple. Shown every time the slides are (launch when not signed in, after Log Out).
- ADDED Camera Tutorial screen (Figma portrait 1545:36476, 36565, 36646, 36726, 36806, 36886, finished 1545:37396; landscape 1545:37750, 37669, 37830, 37910, 37990, 38070):
  - The existing capture camera body and controls (change 157 layout), reused, rotating with the phone the same way; roll filter 200 Color Print, shots-left dial starting at 2.
  - Differences from the capture session: no Back and no End Roll; a "Skip" pill at the top right of the screen.
- ADDED Tips, one at a time, in this order:
  1. Shots Remaining (dial): "Keep track of how many photos you can still take before your roll is complete."
  2. Zoom (wheel): "Drag the dial to zoom in and out."
  3. Flash: "Tap to turn the flash on or off. Turn it on for darker scenes."
  4. Flip: "Tap to switch between the front and back camera."
  5. Take a Photo (shutter): "Press the shutter to snap a photo. Every shot counts, so make it a good one."
  - Each tip is a bubble (`#F6F1E7`, title, body, "tap anywhere to continue" in italics, X) with an arrow pointing at its control.
  - While a tip shows, the screen is dimmed and the control it explains stays bright (a cut-out in the dim); the controls don't react.
  - A tap anywhere or X goes to the next tip.
- ADDED "Try it Out" card after the tips (the existing `StarCard`: washi, walking star, "Try it Out" / "Take 2 photos to finish the tutorial."); a tap anywhere closes it. Then the camera works as normal (zoom, flash, flip, LIVE, shutter) until both shots are taken.
- ADDED Finished: after the 2nd shot, the dial shows 0 and the "Let's get scrapbooking" card shows ("All shots are used up. Your roll is ready to fill the scrapbook." and an "Open Scrapbook" button).
  - "Open Scrapbook" is meant to open the scrapbook tutorial (a later change); until it exists, it goes to Welcome / Sign in.
- ADDED Practice photos: the 2 shots are kept on this phone only, in the app's own temporary storage, for the scrapbook tutorial later. No roll, no SwiftData record, no CloudKit / Supabase; the next tutorial replaces them.
- ADDED Without camera access the tutorial still runs: black viewfinder, the shutter still counts down (nothing saved).
- ADDED Camera access: the system asks when the tutorial opens (right after "Let's Try It"). iOS doesn't ask a second time once access is off, so the capture session (Create Roll and Continue Roll) shows an alert when it opens without access: "Camera Access Needed" / "Turn on camera access in Settings to take photos for your roll." [Draft], with "Open Settings" (the app's page in Settings) and "Not Now" (the camera stays black, as now). Coming back to the app with access on, the camera starts by itself, without leaving the screen.
- ADDED Tech: the five tips are TipKit tips, shown with TipKit's inline tip view (custom style per Figma) in the screen's own overlay, turned with the phone. TipKit's popover tips follow the portrait-locked window, so in landscape they would show sideways. The tutorial itself steps through the tips (not a TipKit tip group) and never invalidates them: a tip group only moves on by invalidating tips, which TipKit remembers for good, so they couldn't show again on the next tutorial. TipKit is configured at app launch with immediate display. The camera body and stage are shared with the capture session (`CameraBodyView`, `CameraStage`).

## Tasks
- [x] Camera Tutorial screen reusing the capture camera body: no Back / End Roll, Skip pill, dial from 2, 200 Color Print, no upload or roll
- [x] TipKit tips (in order) with a custom tip style, dim with a cut-out around the explained control, tap / X to advance, turned with the phone
- [x] "Try it Out" and "Let's get scrapbooking" cards (`StarCard`), 2 practice shots kept in temporary storage
- [x] Onboarding flow: "Let's Try It" → tutorial; Skip and "Open Scrapbook" → Welcome
- [x] Capture session without camera access: "Camera Access Needed" alert with Open Settings / Not Now; the camera starts when the app comes back with access on
- [ ] Tests (tip order and advancing, shot count to 0, Skip / finish routing, no upload); build and run all tests; check on device in portrait and both landscapes (tests done: 412 passed, 1 known issue in `DSContrastTests`; Skip / finish routing lives in `RootView` state, not unit tested; device check pending)

## Out of scope
- The scrapbook tutorial behind "Open Scrapbook"
- Changing the onboarding slides, Welcome / Sign in, or the real capture session (beyond the camera access alert)
- Live sync, Camera Control or volume-button tips
