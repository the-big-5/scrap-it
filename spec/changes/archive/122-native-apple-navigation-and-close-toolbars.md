# 122: Native Apple Navigation Bar and Close Toolbars
Status: Done

## Why
Multiple screens across the app currently hide the native navigation bar (`.toolbar(.hidden, for: .navigationBar)`) and implement custom 44pt circular buttons with 3pt hard drop shadows (`BackCircleButton` and `CircleIconButton`). This diverges from Apple's Human Interface Guidelines, disables the standard iOS swipe-to-pop navigation gesture on pushed screens, and results in non-standard dismiss interactions on modal sheets and immersive screens.

Replacing these custom controls with standard Apple native navigation bar toolbars and Apple system circular close buttons (`xmark.circle.fill`) provides a cohesive iOS experience, consistent touch targets, accessibility, and natural system gesture navigation.

## Touches
ui.md (Global Navigation, Roll flows, Sheets & Modals, Scrapbook Editor, Workbench), flows.md (F1 Navigation, F2 Join Roll, F3 Create Roll, F4 Scrapbook Editor)

## Changes
- MODIFIED `JoinRollView`: Remove custom header with `BackCircleButton`; use standard native navigation bar with system back button.
- MODIFIED `CreateRollSetupView`: Remove custom header with `BackCircleButton`; use standard native navigation bar with system back button.
- MODIFIED `CreateRollFilterView`: Remove custom header with `BackCircleButton`; use standard native navigation bar with system back button.
- MODIFIED `EditProfileView`: Remove custom header with `BackCircleButton` and `CircleIconButton`; use native `.toolbar` with `.topBarLeading` (Cancel) and `.topBarTrailing` (Save / Done) or system dismiss.
- MODIFIED `DeskCollectionView`: Replace custom `BackCircleButton` with native navigation bar back button or `.topBarLeading` item.
- MODIFIED `CreateRollLobbyView`: Replace custom `CircleIconButton(systemName: "xmark")` with native toolbar / Apple circular close component (`xmark.circle.fill`).
- MODIFIED `InviteFriendSheetView`: Replace custom `CircleIconButton(systemName: "xmark")` and `arrow.left` with native navigation bar toolbar items using `xmark.circle.fill` and standard back chevron.
- MODIFIED `WhosHereSheet`: Replace custom `CircleIconButton(systemName: "xmark")` with Apple native circular close button (`xmark.circle.fill`) in `.topBarTrailing` / `.cancellationAction`.
- MODIFIED `ScrapbookBookView`: Replace custom `BackCircleButton` and custom `xmark` button with native Apple navigation toolbar components (`xmark.circle.fill` / native back chevron).
- MODIFIED `ScrapbookEditorView`: Replace custom `BackCircleButton` with native navigation bar toolbar component.
- MODIFIED `WorkbenchView`: Replace custom `BackCircleButton` with native Apple back / close component.
- MODIFIED `CaptureSessionView`: Replace custom back `arrow.left` button with native Apple navigation / close control.
- DEPRECATED / REMOVED `BackCircleButton`: Deprecate or remove unused custom back button component in favor of Apple native navigation.

## Tasks
- [x] **Step 1 — Navigation Stack Pushed Flows**: Update `JoinRollView`, `CreateRollSetupView`, `CreateRollFilterView`, `EditProfileView`, and `DeskCollectionView` to use native SwiftUI `.toolbar` and system back chevrons, restoring interactive swipe-to-pop navigation.
- [x] **Step 2 — Sheets & Modals**: Update `WhosHereSheet`, `InviteFriendSheetView`, and other modal presentation views to use native `.toolbar` with `xmark.circle.fill` styled using Apple system symbol hierarchy and placement.
- [x] **Step 3 — Immersive & Canvas Views**: Update `CreateRollLobbyView`, `CaptureSessionView`, `ScrapbookEditorView`, `ScrapbookBookView`, and `WorkbenchView` to replace custom hard-shadow buttons with Apple native toolbar / symbol components.
- [x] **Step 4 — Clean Up Design System Components**: Clean up or deprecate `BackCircleButton` and adjust `CircleIconButton` references, ensuring no orphan styling remains.
- [x] **Step 5 — Verification & Tests**: Verify all existing automated tests pass with `xcodebuild test` and that navigation across all updated screens behaves consistently with native iOS gestures and buttons.

## Out of scope
- Changing bottom editor tool trays (pencil, scissors, sticker trays).
- Changing camera capture controls (shutter button, flash toggle, zoom controls).
- Modifying business logic, SwiftData schemas, or CloudKit synchronization.
