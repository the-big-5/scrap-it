# 099: End Roll Confirmation and Roll Complete Popups
Status: Done

## Why
Currently, tapping the host-only "End Roll" button in `CaptureSessionView` ends the session immediately without confirmation, and when a roll completes (or ends), the app navigates directly to the Roll Reveal envelope without visual closure.

Adding the Figma-accurate modal popups (`1517:25254` and `1512:26505`) introduces:
1. An "End this roll?" confirmation dialog for the host, showing dynamic shots remaining with correct singular/plural grammar and Cancel / Yes actions.
2. A "Roll Complete!" dialog for all participants when the roll finishes (either when shots reach zero or when the host confirms ending the roll early), prompting them with "Reveal Photos" before navigating to the Roll Reveal screen.
3. Proper adaptation to device orientation while in the camera view.

## Touches
flows.md (F3 step 9: Roll ends), ui.md (Screen: Camera capture popups)

## Changes
- ADDED `ScrapIt/Resources/Assets.xcassets`:
  - `PopupWashiTape`: Top washi tape banner (`96 × 28` pt, rotated `-4°`).
  - `PopupEndRollCanister`: Film canister graphic for popup 1 (`86 × 90` pt).
  - `PopupRollCompleteFilm`: Film roll graphic with exposed strip for popup 2 (`63 × 133` pt).
- ADDED `ScrapIt/Features/Roll/EndRollConfirmationPopupView.swift`:
  - Host-only confirmation modal matching Figma node `1517:25254`:
    - Dimensions: `337 × 294` pt, background `#F6F1E7`, corner radius `32` pt, drop shadow `0px 24px 24px rgba(0,0,0,0.28)`.
    - Washi tape anchored at top center with `-4°` rotation.
    - Centered canister illustration (`86 × 90` pt).
    - Title: `"End this roll?"` (`SF Pro Bold 24pt`, color `#1E1A1A`).
    - Body text: `"You still have 1 shot left. Once you end the roll, you can’t take any more photos."` or `"You still have {N} shots left. Once you end the roll, you can’t take any more photos."` (`SF Pro Regular 15pt`, color `#5B544C`).
    - Buttons:
      - `"Cancel"`: `108 × 52` pt, background `#FCFBF8`, label `#2A241F`, `SF Pro Semibold 17pt`, corner radius `26` pt. Dismisses the popup.
      - `"Yes"`: flex width (`169 × 52` pt), background `#2A241F`, label `#FCFBF9`, `SF Pro Semibold 17pt`, corner radius `26` pt. Confirms ending the roll early and transitions to Popup 2.
- ADDED `ScrapIt/Features/Roll/RollCompletePopupView.swift`:
  - Completion modal for all participants matching Figma node `1512:26505`:
    - Dimensions: `337 × 337` pt, background `#F6F1E7`, corner radius `32` pt, drop shadow `0px 24px 24px rgba(0,0,0,0.28)`.
    - Washi tape anchored at top center with `-4°` rotation.
    - Centered film strip illustration (`63 × 133` pt).
    - Title: `"Roll Complete!"` (`SF Pro Bold 24pt`, color `#1E1A1A`).
    - Body text:
      - Natural completion (0 shots left): `"You've captured every shot! Your memories are ready to be revealed."`
      - Early completion (host ended roll): `"The roll was ended early. Your memories are ready to be revealed."`
    - Button:
      - `"Reveal Photos"`: `293 × 52` pt (full width), background `#2A241F`, label `#FCFBF9`, `SF Pro Semibold 17pt`, corner radius `26` pt. Triggers navigation to the Roll Reveal envelope.
- MODIFIED `ScrapIt/Features/Roll/RollFlowViewModel.swift`:
  - Add state flags: `showEndRollConfirmation: Bool`, `showRollCompletePopup: Bool`, `isRollEndedEarly: Bool`.
  - Update `endSessionManuallyByHost`: sets `isRollEndedEarly = true`, marks session ended, broadcasts roll ended, and opens `showRollCompletePopup` instead of directly navigating to reveal.
  - Update slot count exhaustion and remote `onRollEnded` handlers: show `showRollCompletePopup`.
  - Add `proceedToRollReveal()`: performs `finalizeSessionAndOpenScrapbook()` to navigate to `AppRoute.rollReveal(scrapbook.id)`.
- MODIFIED `ScrapIt/Features/Roll/CaptureSessionView.swift`:
  - Wire `endRollButton` to toggle `flowViewModel.showEndRollConfirmation = true`.
  - Add modal overlay presenting `EndRollConfirmationPopupView` or `RollCompletePopupView` with dimmed backdrop (`Color.black.opacity(0.4)`).
  - Adapt popup rotation dynamically based on device orientation (`UIDeviceOrientation` / `symbolRotation`).
- ADDED / MODIFIED unit tests in `ScrapItTests/Roll/RollFlowViewModelTests.swift`:
  - Verify popup state transitions, proper singular/plural body strings, and navigation trigger on "Reveal Photos".
- Specs at merge (`/merge-change`):
  - Document the confirmation dialog and completion popup in `spec/flows.md` and `spec/ui.md`.

## Tasks
- [x] Export and add assets (`PopupWashiTape`, `PopupEndRollCanister`, `PopupRollCompleteFilm`) to `Assets.xcassets`
- [x] Implement `EndRollConfirmationPopupView.swift` following Figma node `1517:25254`
- [x] Implement `RollCompletePopupView.swift` following Figma node `1512:26505` with natural and early finish variants
- [x] Update `RollFlowViewModel.swift` with popup states, grammar strings, and deferred reveal navigation
- [x] Integrate popups with orientation adaptation into `CaptureSessionView.swift`
- [x] Add unit tests for popup flow and copy in `ScrapItTests`

## Out of scope
- Modifying the Roll Reveal envelope view (`RollRevealView`) or scrapbook editor
- Allowing non-host participants to initiate "End Roll"
- Changes to underlying CloudKit or Supabase broadcast payloads
