# 005: Create Roll and Share Room Lobby Redesign
Status: Done

## Why
The roll creation and lobby (share room) designs have been updated in Figma to match the new warm kraft / stationery visual direction and improve user experience:
1. "Camera Roll" menu (`984:3163`): Accessed from tapping the camera on Workbench, giving access to Create Roll and Join a Roll.
2. "Create Roll Setup" (`984:3556`): Redesigned with warm gradient header, decorative stationery illustrations, "Name your roll" input, and styled film sprocket shot count picker (24, 36, 48, 72) with friendship size guidance ("4-6 friends").
3. "Choose Filter" (`675:5759`): Updated header decoration, title typography, and film canister filter picker.
4. "Share Room Lobby" (`1011:5883`, `768:1382`): Redesigned lobby displaying roll name, stats summary (joined friends count, total shots), a dynamic participant avatar grid (Host, You, joined members), and primary "Start Roll" CTA.
5. "Invite Friend Sheet" (`768:1483`): The QR code, 6-character monospace roll code boxes, and "Copy link" are moved from the main screen into a dedicated medium-detent bottom sheet triggered by the top-right button in the navigation bar.

In addition, to comply with the project rule (**"Always use PascalCase and no numbers for code files (e.g., `PrimaryButton.swift`, `RollViewModel.swift`; no numbers like `View2.swift` or `ButtonV1.swift`)"**), the existing numbered step views and structs will be renamed to clean descriptive PascalCase names without numbers.

## Touches
ui.md (Create Roll setup, choose filter, share room lobby), flows.md (F2, F3 lobby & invite sheet presentation), tech.md (Features/Roll/ filenames, struct names, AppRoute enum cases, no data model schema changes)

## Figma Source
File key: `ujlkuWobqxyvtQwh5plhGF`
- `984:3163`: CameraClik (Create / Join roll menu from workbench)
- `984:3556`: CreateRoll (Name roll & choose shots)
- `675:5759`: ChooseFilter (Filter canister picker & carousel)
- `1011:5883`: Share Room Lobby empty / host only (Header stats, avatar, Start Roll)
- `768:1382`: Share Room Lobby with joined participants (5 joined, avatar grid)
- `768:1483`: Invite Friend Bottom Sheet (QR code, 6-box roll code, Copy link)

## Changes
- ADDED: Decorative header illustrations and stationery assets for Create Roll and Lobby flows into `Assets.xcassets`.
- RENAMED / REFACTORED (Enforcing Rule: No numbers in filenames or class/struct names):
  - `CreateRollStep1View.swift` (`struct CreateRollStep1View`) renamed to `CreateRollSetupView.swift` (`struct CreateRollSetupView`).
  - `CreateRollStep2FilterView.swift` (`struct CreateRollStep2FilterView`) renamed to `CreateRollFilterView.swift` (`struct CreateRollFilterView`).
  - `CreateRollStep3ShareRoomView.swift` (`struct CreateRollStep3ShareRoomView`) renamed to `CreateRollLobbyView.swift` (`struct CreateRollLobbyView`).
  - Updated `AppRoute` in `Core/Services/Navigator.swift` to use descriptive, number-free route cases (`createRollSetup`, `createRollFilter`, `createRollLobby`).
- MODIFIED: `CreateRollSetupView.swift` (`CreateRollSetupView`)
  - Top header styling with warm gradient and stationery artwork.
  - "Name your roll" section with subtitle and styled text field.
  - "Choose your shots" film strip selector with active frame styling and participant guide text ("4-6 friends").
  - Primary bottom pill button "Next".
- MODIFIED: `CreateRollFilterView.swift` (`CreateRollFilterView`)
  - Integrated header styling matching the setup screen.
  - Film canister visual selection (B&W vs Color Print) with current shot count badge.
  - Primary bottom pill button "Next".
- MODIFIED: `CreateRollLobbyView.swift` (`CreateRollLobbyView`)
  - Replaced inline QR code and code text with the new Room Lobby layout.
  - Header: Large roll title, stats row showing `person.2` joined count and `camera` shots count.
  - Top-right toolbar button (`qrcode` / invite icon) to present the Invite sheet.
  - Participant avatar grid displaying host badge ("Nabiel (Host)"), current user ("(You)"), and joined peers with profile photo or monogram initial badge fallback.
  - Primary bottom pill button "Start Roll" (host-enabled; disabled or showing "Waiting for host..." for guests).
- ADDED: `InviteFriendSheetView.swift` in `Features/Roll/Components/`
  - Presented as a SwiftUI `.sheet` with `.presentationDetents([.medium])`.
  - Displays "Invite friend" title.
  - Center QR code representation.
  - "Roll code:" header with 6 individual styled monospace character boxes.
  - Underlined "Copy link" button with clipboard copy action and feedback.
- MODIFIED: `RollFlowViewModel.swift`
  - Support `isInviteSheetPresented` state flag.
  - Update navigation triggers to use number-free route names.
  - Ensure reactive participant list updates trigger smooth avatar grid transitions.
- MODIFIED: `MainTabView.swift`
  - Update route destinations to use the new number-free view structs (`CreateRollSetupView`, `CreateRollFilterView`, `CreateRollLobbyView`).

## Tasks
- [x] Export and import new header illustrations and stationery assets from Figma into `Assets.xcassets` (`@1x`, `@2x`, `@3x`)
- [x] Update `AppRoute` enum cases in `Core/Services/Navigator.swift` to remove numbers (`createRollSetup`, `createRollFilter`, `createRollLobby`)
- [x] Rename `CreateRollStep1View.swift` to `CreateRollSetupView.swift` (`CreateRollSetupView`) and redesign to match Figma node `984:3556` (header gradient, section headers, film strip selector, Next button)
- [x] Rename `CreateRollStep2FilterView.swift` to `CreateRollFilterView.swift` (`CreateRollFilterView`) and redesign to match Figma node `675:5759` (filter picker canister presentation, Next button)
- [x] Rename `CreateRollStep3ShareRoomView.swift` to `CreateRollLobbyView.swift` (`CreateRollLobbyView`) and redesign to match Figma nodes `1011:5883` and `768:1382` (title, stats row, avatar grid, top-right invite button, Start Roll CTA)
- [x] Implement `InviteFriendSheetView.swift` in `Features/Roll/Components/` with QR code, 6-box roll code display, and "Copy link" clipboard handler
- [x] Wire the top-right button in `CreateRollLobbyView` to present `InviteFriendSheetView`
- [x] Update `MainTabView.swift` and `RollFlowViewModel.swift` to bind to the renamed views and routes
- [x] Verify non-host participant state in `CreateRollLobbyView` (guest sees "Waiting for host...", cannot trigger start)
- [x] Verify navigation transitions from Workbench camera tap -> Setup -> Filter -> Lobby -> Capture Session

## Out of scope
- Capture session camera UI updates (`708:4941`).
- Join Roll QR camera scanner implementation (remains draft/manual code input).
- CloudKit schema changes or backend service alterations.
- Profile shelf or scrapbook grid redesigns.
