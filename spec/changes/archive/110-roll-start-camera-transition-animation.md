# 110: Roll Start Camera Transition Animation
Status: Done

## Why
When the host taps "Start Roll" in `CreateRollLobbyView` (or when a participant is moved to capture when the roll goes live), the app currently executes an immediate navigation push directly to `CaptureSessionView` without a physical entrance animation.

To match the analog skeuomorphic return transition (changes 086, 100), entering the camera should feel like loading a fresh disposable camera and preparing it for shooting:
1. **Initial Fade to Blank Page:** Tapping "Start Roll" in `CreateRollLobbyView` (or participant detection of `.live` roll status) initiates the transition by cleanly cross-fading from the lobby view into a completely blank paper background (`#F4EFE6`). No camera elements are visible yet.
2. **3D Camera Intro Animation:** Once the view settles on the blank page, the loading animation begins (reference: `CameraIntro.dc.html`, 5.6s total timeline):
   - **Phase 1 (0.0s - 1.6s) - Camera Arrival & Flip:** The disposable camera flies into the blank frame from distance in 3D perspective and rotates horizontally to present its back chamber.
   - **Phase 2 (1.6s - 2.8s) - Film Loading:** The camera back door unlocks and swings open with subtle dust puff particles; the film canister—displaying the exact configured variant selected during roll setup (`FilterCanisterColor` for Color Print 200, or `FilterCanisterBW` for Cinematic 400 B&W)—drops into the chamber; the film leader pulls across to the take-up spool.
   - **Phase 3 (2.8s - 3.7s) - Door Latching:** The take-up spool turns and advances the film leader; the back door swings shut; the slide latch clicks into locked position with haptic ripples.
   - **Phase 4 (3.7s - 4.3s) - Winding & Iris Contraction:** The thumb advance wheel winds with audible/haptic clicks; the shots dial advances; the mechanical iris diaphragm constricts over the viewfinder.
   - **Phase 5 (4.3s - 5.6s) - Viewfinder Zoom & UI Entrance:** The camera zooms deeply into the viewfinder window with an expanding circular clip aperture, resolving into the final camera canvas. The production camera UI controls (spherical shutter dome, knurled zoom wheel, dedicated host end roll button, flash button, back button, flip button, shots dial) spring and slide into their exact production positions while the iris opens to reveal the live preview.
3. An optional "Tap anywhere to skip" hint allows the user to immediately finish the transition into active camera capture.
4. The production camera layout, controls, and colors implemented in `CaptureSessionView` remain completely untouched; only the entrance animation sequence is introduced.

## Touches
flows.md (F3: Start Roll), ui.md (Camera intro animation & Capture session entrance), tech.md (Navigation & CameraIntroTransitionOverlay)

## Changes
### 1. Camera Intro Transition Overlay
- ADDED `ScrapIt/Features/Roll/CameraIntroTransitionOverlay.swift`:
  - Full-screen transition view presented above the navigation stack during camera entrance.
  - Stage 1: Cream paper background fade (`#F4EFE6`) with grain texture.
  - Stage 2: 3D perspective camera rig performing arrival fly-in, Y-axis flip, back door opening, film canister insertion, leader pull, spool turn, door latching, thumb wheel winding, and deep zoom into viewfinder.
  - Film canister dynamically uses the roll's configured `RollFilter` variant: `FilterCanisterColor` for `.colorPrint200` or `FilterCanisterBW` for `.cinematicBW400`.
  - Stage 3: Animated assembly of the project's exact camera deck UI elements (spherical shutter dome, knurled zoom wheel, flash, flip, back, dial, host end roll button) with mechanical iris opening over live preview.
  - Stage 4: "Tap anywhere to skip" gesture recognizer to fast-forward transition directly into live capture.
  - Audio/Haptics: Synchronized mechanical clicks and ratchet haptic feedback during film loading and wheel winding.

### 2. Navigation and Flow Coordination
- MODIFIED `ScrapIt/App/Navigation/AppRouter.swift`:
  - Add camera intro transition states (`isShowingCameraIntro`, `cameraIntroPhase`).
  - Provide `startCameraIntro(onComplete:)` and `skipCameraIntro()` coordination methods.
- MODIFIED `ScrapIt/App/MainShellView.swift`:
  - Mount `CameraIntroTransitionOverlay` in the shell overlay stack above `NavigationStack` alongside `CameraReturnTransitionOverlay`.
- MODIFIED `ScrapIt/Features/Roll/CreateRollLobbyView.swift` & `RollFlowViewModel.swift`:
  - Trigger `startCameraIntro` when the host starts the roll or when a participant detects the session transitioning to `.live`.
  - Push `.captureSession` underneath the transition overlay and complete handoff smoothly without UI flickering or abrupt orientation jumps.

### 3. Camera Visual Assets
- ADDED `ScrapIt/Features/Roll/Components/CameraIntroComponents.swift`:
  - Film canister, film leader strip, back door, thumb wheel, and particle effects for the loading sequence.
  - Reuses existing `Image("DeskDisposableCamera")`, `Image("CameraBodyShape")`, and `CameraIrisDiaphragmView` for visual consistency.

## Tasks
- [x] Implement cross-fade from `CreateRollLobbyView` to a completely blank paper background (`#F4EFE6`) prior to camera arrival
- [x] Implement `CameraIntroTransitionOverlay` with multi-phase animation timeline matching `CameraIntro.dc.html` timings
- [x] Add 3D perspective camera arrival, horizontal flip, door swing, and film canister insertion
- [x] Bind film canister visual to the roll's configured filter variant (`FilterCanisterColor` for Color Print 200 vs `FilterCanisterBW` for Cinematic 400 B&W)
- [x] Add film leader stretch, take-up spool rotation, door latching, and thumb wheel winding sequence
- [x] Implement viewfinder deep-zoom and expanding circular aperture transition into `CaptureSessionView`
- [x] Animate camera controls (shutter dome, knurled zoom wheel, host end roll, flash, flip, back, shots dial) into their production layout positions
- [x] Add mechanical iris diaphragm opening over live viewfinder at animation completion
- [x] Implement "Tap anywhere to skip" action for immediate transition to active camera
- [x] Hook transition into `RollFlowViewModel` and `MainShellView` for both host and joining participants
- [x] Add unit tests verifying transition phase states, navigation synchronization, and skip handling
- [x] Run test suite to verify no regressions

## Out of scope
- Any design changes to the live `CaptureSessionView` layout, controls, or dimensions.
- Changes to the camera return transition (changes 086, 100).
- Modifying roll creation setup or filter selection screens.
