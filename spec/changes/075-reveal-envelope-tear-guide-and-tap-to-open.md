# 075: Roll Reveal Envelope Tear Guide, Interactive Slicing Haptics & Tap-to-Open
Status: Done

## Why
On the Roll Reveal screen after finishing a capture session, the closed kraft envelope shows only the roll title and photo count label, with no visual tear guide or instruction telling the user how to open it. Opening currently requires dragging strictly across the top `49` pt flap strip (`RevealEnvelopeView`), which offers little progressive feedback while slicing and ignores taps.

Adding the translucent dashed tear-guide overlay from Figma (`1335:66589` / node `1515:27195`), a subtle `"Swipe or tap to open"` instruction when ready, a progressive tear-seam peel animation with periodic slicing haptics, and tap-anywhere-on-envelope opening makes the reveal immediately understandable and tactile without requiring a swipe.

## Touches
flows.md (F3 step 10: Roll Reveal), ui.md (Screen: Roll Reveal)

## Changes
- MODIFIED `ScrapIt/Features/Reveal/RollRevealViewModel.swift`:
  - Add `static let openHintText = "Swipe or tap to open"` and expose computed `envelopeStatusText: String?` (returns `printingText` while `isDeveloping`, `readyText` during `showsReadyText`, `openHintText` once `canTear && !isTorn`, and `nil` once `isTorn`).
  - Keep `tear()` gating unchanged (`guard stage == .envelope, canTear else { return }`) so neither swiping nor tapping opens the envelope prematurely during the initial developing window.
- MODIFIED `ScrapIt/Features/Reveal/Components/RevealEnvelopeView.swift`:
  - **Figma `1335:66589` (`1515:27195`) tear-guide strip:** Overlay a translucent rounded pill bar (`285 × 20` pt, `#D9D9D9` at `60%` opacity, `cornerRadius: 24`, overhanging the `260` pt envelope cleanly at `y ≈ 47` along the flap seam) containing a single centered row of white horizontal dashes (omitting the accidental wrapped `-` above the label in the Figma mockup).
  - **Idle shimmer, sliding pointed-finger cue & progressive slicing animation:** While `canTear && !isTorn` (and `!reduceMotion`), animate both a sweeping shimmer highlight across the dashed pill and a sliding pointed-finger icon (`hand.point.up.fill` with fingertip contact glow) gliding smoothly left-to-right across the tear seam (`stripDrag == 0`, pausing/hiding as soon as the user starts slicing or tears it). While dragging across the tear strip, progressively separate/reveal the tear seam in sync with drag travel as the top flap peels and tilts upward (`stripDrag` / `stripRotation` / `stripOffset`), and fade out the guide pill cleanly once torn.
  - **Interactive slicing haptics & developing lock feedback:** Fire light paper-rip step haptics (`sliceTickCount`) every ~`20` pt of horizontal slice progress while `canTear && !isTorn`, retain the heavy completion snap haptic (`isTorn`), and give a gentle strip wiggle + soft nudge haptic (`lockedNudgeCount`) if the user taps or tries to tear while `!canTear` (`Reduce Motion` skips the wiggle/shimmer while keeping haptics and transitions).
  - **Clickable envelope (`tap-to-open`):** Allow tapping anywhere on the envelope body or tear strip (via non-interfering `onTapGesture` alongside `.highPriorityGesture(tearGesture)` on the strip) to trigger the same full strip tear-off animation, heavy haptic, and `onTear()` callback when `canTear`; update VoiceOver accessibility hints to `"Swipe across the top or tap to tear open"`.
- MODIFIED `ScrapIt/Features/Reveal/RollRevealView.swift`:
  - Keep existing `RevealCuttingMat` background unchanged.
  - Bind the caption below the envelope to `viewModel.envelopeStatusText` (`"Printing your photos…"`, `"Your photos are ready!"` for `2.5` s, and `"Swipe or tap to open"` once ready until torn).
- MODIFIED `ScrapItTests/Reveal/RollRevealTests.swift`:
  - Add unit tests verifying `envelopeStatusText` transitions across developing (`printingText`), newly arrived (`readyText`), ready/unlocked (`openHintText`), and torn (`nil`), plus locked vs. unlocked `tear()` behavior.
- Specs at merge (`/merge-change`):
  - `flows.md` (F3 step 10) and `ui.md` (`Screen: Roll Reveal`): document the Figma translucent dashed tear-guide strip, `"Swipe or tap to open"` caption when ready, progressive slicing animation & step haptics, and tap-to-open support.

## Tasks
- [x] Add `openHintText` and `envelopeStatusText` to `RollRevealViewModel.swift`
- [x] Implement Figma `1335:66589` translucent dashed tear guide, idle shimmer, sliding pointed-finger gesture animation, progressive slicing separation/peel animation, periodic slicing tick haptics, locked wiggle nudge, and tap-anywhere-to-open in `RevealEnvelopeView.swift`
- [x] Update `RollRevealView.swift` to display `viewModel.envelopeStatusText` cleanly under the envelope on `RevealCuttingMat`
- [x] Add unit tests for `envelopeStatusText` states and locked/ready open flow in `RollRevealTests.swift`, and run tests on iOS Simulator

## Out of scope
- Replacing the full-screen `RevealCuttingMat` background with the top/bottom wood framing from Figma `1335:66589`
- Multi-finger or curved arbitrary scissor slicing on the envelope (linear horizontal tear seam + tap-to-open only)
- Changing the developing 10-second timeout (`tearUnlockDelay`) or End Roll sync behavior
