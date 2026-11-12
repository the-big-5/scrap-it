# 106: Workbench Film Rolls Interaction, Resume Roll Screen & Host-Safe Leave

Status: Done

## Why
On the Home Workbench (`WorkbenchView`), `DeskToolbox` (change `104`) and `DeskDisposableCamera` are interactive, while the 3 film canisters resting on the cutting mat (`DeskFilmRoll2`, `DeskFilmRoll3`, `DeskFilmRoll4` in Portrait; `iPadCanisters` in iPad Landscape from change `105`) are still static artwork. Making the film canisters interactive completes the desk navigation trio and fulfills the `[Open]` requirement in `flows.md` (`F3` step 4) to reopen in-progress rolls:
1. Tapping any of the 3 film canisters on the Workbench (on both Portrait and iPad Landscape) blurs and dims the desk, hides the floating tab bar, glides and fans the 3 canisters into the Figma `1235:21168` center cluster with a short spring animation and haptic feedback, and automatically navigates to **"Resume Roll"**.
2. **"Resume Roll"** reuses `Core/DesignSystem/DeskCollection/` (`DeskCollectionView`, `DeskEmptyStateView`, adaptively sized for iPhone and iPad) and switches cleanly between:
   - **Empty state (`1537:25997`):** craft camera, film canisters, amber film leader, and star characters above `"No roll in progress...yet!"`, `"Your next little moments are waiting to be captured. Start a roll and make memories with your friends."`, and `"Create Roll"` primary pill button routing to `CreateRollSetupView`.
   - **Populated list (`1537:26016`):** local in-progress `CaptureSession`s (`status != .ended`, both `.waiting` lobby and `.live` capture), newest `startTime` first, rendered as upright filter canisters (`400 B&W` or `200 Color Print`) feeding horizontal ink film strips showing roll name, `{N} joined`, `{slotsUsed}/{rollSize} shots`, and `dd/MM/yyyy` date.
3. Because another participant may capture shots, end the roll, remove the user, or become the new host while this user is on the Workbench, **"Resume Roll"** silently refreshes each listed room via CloudKit (`fetchRoom`) on screen appear and before entering a roll — keeping `hostUserID`, joined count, shot count, and status accurate, finalizing remotely ended rolls into **Roll Reveal** (or notifying/cleaning up if already finalized into a `Scrapbook`), and pruning deleted/removed rooms.
4. Long-pressing a roll card supports **Leave Roll** (for host or participant) and **Delete Roll** (host only). Leaving as host when other participants are still in the room automatically transfers `hostUserID` to the next participant and removes only the host's `RollParticipant` record in CloudKit without destroying the shared `CKRecordZone`, allowing friends to keep shooting and finalize the roll safely.

## Touches
flows.md (F3: Roll), ui.md (Screen: Home, Screen: Resume Roll), tech.md (CloudKit roll rooms, Code structure)

## Changes
- ADDED `ScrapIt/Assets.xcassets/`:
  - `Workbench/` unclipped interactive canister layers derived from Figma `1235:21168` (`DeskFilmRollYellow`, `DeskFilmRollRed`, `DeskFilmRollGreen`, or normalized interactive equivalents) so the 3 canisters animate cleanly from their idle positions (Portrait `853:1703` and iPad Landscape `1563:34278`) to screen center without frame-edge clipping.
  - `DeskCollection/` empty-state illustration assets from Figma `1537:25997` (`RollEmptyLeader`, `RollEmptyStarLeft`, `RollEmptyStarTop`, `RollEmptyStarRight`, reusing existing `DeskDisposableCamera` / `FilterCanisterColor` / `FilterCanisterBW` where identical) and optional crisp film-canister sprite overrides if needed beyond `FilterCanisterBW` / `FilterCanisterColor`.
- ADDED `ScrapIt/Core/DesignSystem/DeskCollection/RollStripCard.swift`:
  - Data-agnostic Figma `1537:26016` row component rendering the upright `90°`-rotated film canister (`FilterCanisterBW` or `FilterCanisterColor`) paired with an adaptively wide `#2A241F` film strip with white top/bottom sprocket perforations, roll title, `person.2` `{N} joined`, `camera` `{slotsUsed}/{rollSize} shots`, and `dd/MM/yyyy` date, plus tap and long-press (`contextMenu`) actions (`Leave Roll`, and `Delete Roll` when `isHost`).
- ADDED `ScrapIt/Features/Home/Components/RollEmptyIllustration.swift` and `InteractiveRollsView.swift`:
  - `RollEmptyIllustration`: Collage from Figma `1537:25997` rendered inside `DeskEmptyStateView` when `activeRolls.isEmpty`.
  - `InteractiveRollsView`: Renders the 3 persistent canister sprites (`200`, `400`, `100`) that glide/fan from their Variant idle placements to the centered `1235:21168` cluster with secondary stagger and haptic feedback.
- MODIFIED `ScrapIt/Core/Services/RollRoomService.swift`:
  - Extend `RollRoomServicing` & `CloudKitRollRoomService` with a non-destructive `leaveAsHostHandover(code:zoneOwnerName:leavingUserID:nextHostUserID:)` (or update `leaveRoom` / helper): saves `RollSession["hostUserID"] = nextHostUserID` in CloudKit, deletes only the leaving host's `RollParticipant` record if `zoneOwnerName == nil` (preserving the host's `CKRecordZone` + `CKShare` so friends can continue), or leaves the shared zone after updating `hostUserID` if `zoneOwnerName != nil`.
- MODIFIED `ScrapIt/App/Navigation/NavigationRoutes.swift` and `ScrapIt/App/MainShellView.swift`:
  - Add `case rolls` to `DeskCollectionKind`.
  - Inject `currentUser`, `roomService`, and `archiveSync` into `WorkbenchViewModel`.
  - Map `.deskCollection(.rolls)` in `MainShellView.destinationView(for:)` to `"Resume Roll"`, composing `DeskCollectionView`, scrollable `RollStripCard` list, `RollEmptyIllustration` inside `DeskEmptyStateView`, CloudKit refresh on `.task` / `.onAppear`, Leave / Delete confirmation dialogs, and remote-ended / exit alert handling.
- MODIFIED `ScrapIt/Features/Home/WorkbenchLayout.swift`:
  - Remove static `DeskFilmRoll2`, `DeskFilmRoll3`, `DeskFilmRoll4` from `deskItems` (Portrait) and `iPadCanisters` (iPad Landscape) so one persistent `InteractiveRollsView` layer animates smoothly on tap.
  - Add Portrait (`402×874`, Figma `853:1703` idle -> `1235:21168` active) and iPad Landscape (`1210×834`, `1563:34278` idle -> centered scaled cluster) placements and rotations for the 3 canisters (`activeCanisterPlacements`), keeping `everyDeskAssetIsUniqueAndInsideTheFrame` and `086`/`100`/`104`/`105` layout metrics intact.
- MODIFIED `ScrapIt/Features/Home/WorkbenchViewModel.swift` and `WorkbenchView.swift`:
  - Add `isRollsActive` (hiding floating tab bar alongside `isCameraActive || isToolboxActive`, blurring/dimming the desk, and gating `camera`, `toolbox`, and `tutorialBook` taps while active).
  - Add `activateRolls()` + `cancelRollsTransition()` -> ~`0.85s` glide/fan + haptic -> push `.deskCollection(.rolls)`.
  - Add `activeRolls` (`CaptureSession` with `statusRaw != SessionStatus.ended.rawValue`, sorted by `startTime` descending), `refreshActiveRolls()` (`fetchRoom` per session, syncing `hostUserID`, `participantIDs`, `participantNames`, `slotsUsed`, `statusRaw`, `endTime`, `shareURLString`, `rollKey`, and cleaning up sessions returning `.removed`/`.deleted` or missing `currentUser`), and `openRoll(_:)`:
    - Re-checks `fetchRoom` online when `ckRecordName != nil`, then:
      - `.waiting` → sets `sessionStore.activeSession` and pushes `.createRollLobby`
      - `.live` → sets `sessionStore.activeSession` and pushes `.captureSession`
      - `.ended` → if no local `Scrapbook` exists for `session.id`, finalizes (`sessionStore.finalizeActiveSession()` + background `archiveSync.syncRoom(for:)`) and pushes `.rollReveal(scrapbook.id)`; otherwise notifies `"This roll has ended. Find its scrapbook in Resume Editing or Library."` and deletes the stale `CaptureSession`.
  - Add `requestLeaveRoll(_:)`, `confirmLeaveRoll()`, `requestDeleteRoll(_:)`, `confirmDeleteRoll()` implementing `4B-1` host handover on leave, participant leave, and host room deletion.
  - Ensure `CaptureSessionView` / `RollFlowViewModel.cameraDidAppear()` also starts `cloudService.startLiveSessionPolling` when `sessionStore.activeSession` is resumed directly into `.captureSession` (since `MainShellView` recreates `RollFlowViewModel` on roll re-entry).
- Specs at merge (`/merge-change`):
  - `flows.md` (F3: opening in-progress rolls from `"Resume Roll"` and host handover on leave), `ui.md` (Screen: Home canisters + Screen: Resume Roll), `tech.md` (`RollRoomServicing`, `DeskCollection`, `WorkbenchViewModel`).

## Tasks
- [x] Download and add unclipped Workbench canister sprites (`1235:21168`) and empty-state craft illustration assets (`1537:25997`) to `Assets.xcassets`
- [x] Build `RollStripCard.swift` in `Core/DesignSystem/DeskCollection/` and `RollEmptyIllustration.swift` + `InteractiveRollsView.swift` in `Features/Home/Components/`
- [x] Extend `RollRoomServicing` / `CloudKitRollRoomService` with host-handover-safe leave (`leaveAsHostHandover`) while preserving `CKRecordZone` + `CKShare` for remaining participants
- [x] Update `WorkbenchLayout.swift`, `WorkbenchView.swift`, and `WorkbenchViewModel.swift` with Portrait & iPad Landscape canister click animations, `activeRolls` querying, CloudKit `fetchRoom` sync, tap routing (`.waiting` -> lobby, `.live` -> camera, `.ended` -> reveal/notice), and long-press Leave (with host handover) / Delete actions
- [x] Wire `.deskCollection(.rolls)` in `NavigationRoutes.swift` and `MainShellView.swift`, and ensure `RollFlowViewModel.cameraDidAppear()` starts live polling on resumed `.captureSession` entries
- [x] Update/add tests across `WorkbenchLayoutTests.swift`, `WorkbenchViewModelTests.swift`, and `RollRoomTests.swift`, run `xcodebuild test` on both iPhone and iPad simulators, and visually verify UI

## Out of scope
- Discovering unknown active CloudKit rolls via `listRooms()` across devices (`106` refreshes local `CaptureSession`s via `fetchRoom`)
- Triggering automatic host handover when tapping Back in `CaptureSessionView` or X in `CreateRollLobbyView` (those intentionally keep the user in the roll so they can resume it from `"Resume Roll"`)
- Adding a `"Join a Roll"` button inside `"Resume Roll"`'s empty state (`1537:25997` only includes `"Create Roll"`)
- Modifying the `DeskBookTutorial` (`openTutorial()`) flow or editing main spec files prior to `/merge-changes`
