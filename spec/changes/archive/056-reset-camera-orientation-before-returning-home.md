# 056: Reset Camera Orientation Before Returning Home
Status: Done

## Why
Currently, exiting `CaptureSessionView` (both when returning to the Homepage via the back button and when navigating to the Scrapbook upon roll completion) relies on `.onDisappear` to reset orientation back to portrait via `OrientationLock.set(.portrait)`.

Because navigation transitions occur before or concurrently with `.onDisappear`, portrait-only destination views such as `HomeView` momentarily render while the window scene is still in landscape. This causes a momentary broken, stretched, or flashing landscape layout before the asynchronous geometry update restores portrait orientation.

By setting the orientation lock back to portrait immediately before triggering navigation transitions across all exit routes from `CaptureSessionView`, the app ensures destinations render directly in portrait.

## Touches
tech.md (Orientation), ui.md (Capture session), flows.md (F2: Capture Flow)

## Changes
### 1. Pre-Navigation Orientation Reset on Camera Exits
- MODIFIED `CaptureSessionView`:
  - Reset orientation lock to `.portrait` immediately before triggering back navigation (`returnToHomepage`).
  - Reset orientation lock to `.portrait` immediately before opening scrapbook on roll finalization (`finalizeSessionAndOpenScrapbook`).
- MODIFIED `RollFlowViewModel`:
  - Ensure orientation lock is explicitly set to `.portrait` prior to popping to root or replacing navigation stack.

### 2. Orientation Lock Lifecycle Cleanliness
- MODIFIED `OrientationLock` / `CaptureSessionView`:
  - Retain safety cleanup in `.onDisappear` while ensuring pre-navigation orientation requests prevent landscape rendering in destination views.
  - Stop motion updates and reset simulated landscape side cleanly when exiting.

## Tasks
- [x] Set orientation lock to `.portrait` prior to navigation state changes on all `CaptureSessionView` exit paths (back button and roll completion).
- [x] Ensure `HomeView` and `ScrapbookEditorView` render directly in portrait without momentary landscape flash.
- [x] Add unit tests verifying orientation lock changes to portrait upon camera exit actions.
- [x] Run full test suite to verify no regressions in camera orientation or navigation.

## Out of scope
- Adding landscape orientation support to Homepage or Scrapbook screens.
- Modifying camera viewfinder layout or motion rotation handling while the camera session is active.
