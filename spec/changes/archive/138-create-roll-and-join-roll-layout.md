# 138: Update Copywriting and Layout for Create Roll and Join Roll Code Alignment
Status: Done

## Why
- Create Roll (`CreateRollSetupView`) still shows `CreateRollHeaderDecoration`, older copywriting (`"Choose your shots."` / `"How many memories?"`), `"Bali ’27"` placeholder, and horizontal padding around `FilmStripShotSelector`, whereas the updated design in Figma `1717:68794` removes the header decoration, moves `"A trip, a night out, a season."` into the text field placeholder, uses `"Pick how many photos to shot"`, and runs `FilmStripShotSelector` full-width edge-to-edge.
- Join Roll (`JoinRollView`) currently pins `"Enter code"` and the 6 code boxes to `.padding(.horizontal, 22)` with `.frame(maxWidth: .infinity, alignment: .leading)`, pushing the code block too far toward the left edge instead of centering the `319` pt code-box block beneath `"Turn on AirDrop to accept the invite"` as shown in Figma `1663:46361`.

## Touches
- `ui.md` (`Screen: Create Roll Setup`, `Screen: Join a Roll`)
- `flows.md` (`F3: Roll` step 2)

## Changes
- MODIFIED `CreateRollSetupView` (Figma `1717:68794`):
  - Remove `CreateRollHeaderDecoration` so the screen uses the clean `DSColor.Kraft.lightActive` (`#F7F2EB`) background.
  - Keep the native Liquid Glass navigation bar back button (`.toolbar(.visible, for: .navigationBar)`).
  - Keep `"Create Roll"` (34 pt Bold) and `"Capture moments with limited shots,\nrevealed when the roll is complete."` (15 pt Medium) with 16 pt horizontal padding.
  - Update `"Name your roll"` to 20 pt Regular (`Title3/Regular`), remove the separate `"A trip, a night out, a season."` subtitle above the field, and move `"A trip, a night out, a season."` (15 pt Italic) into the `TextField` placeholder (replacing `"Bali ’27"`).
  - Update the roll name `TextField` to 52 pt height, 20 pt corner radius, and 1 pt stroke with 16 pt horizontal padding.
  - Replace `"Choose your shots."` + `"How many memories?"` with `"Pick how many photos to shot"` (17 pt Regular, 16 pt horizontal padding).
  - Make `FilmStripShotSelector` full-width edge-to-edge (remove the 20 pt horizontal padding around it), and update `FilmSprocketStrip` hole count calculation (`ceil((width + 3) / 7)` with clipping) so the white sprocket dots extend all the way to both screen edges; keep the centered italic friend-count guidance below the strip and the bottom `"Next"` primary `DSButton`.
  - Use explicit dark text (`Color.black` / `DSColor.Brand.primary`) and `.toolbarColorScheme(.light, for: .navigationBar)` so text and controls never turn white in Dark Mode.
- MODIFIED `JoinRollView` (Figma `1663:46361`):
  - Center the `319` pt-wide code-entry block (`6 × 49` pt `RollCodeBox` + `5 × 5` pt spacing) horizontally across any iPhone/iPad screen width instead of left-aligning it at 22 pt from the leading edge.
  - Keep `"Enter code"` (20 pt Regular) and `joinErrorMessage` left-aligned to the leading edge of that centered `319` pt code-box group so `"Enter code"` consistently aligns directly beneath the start of the centered `"Turn on AirDrop to accept the invite"` text across devices.
  - Use explicit `Color.black` (instead of `Color.primary`) for `"Turn on AirDrop to accept the invite"` and `"Enter code"`, `#E6E6E6` divider overlay, and `.toolbarColorScheme(.light, for: .navigationBar)` so text stays black in Dark Mode.
  - Keep the native Liquid Glass navigation bar back button and the bottom `"Join Roll"` primary `DSButton`.

## Tasks
- [x] Update `ScrapIt/Features/Roll/CreateRollSetupView.swift` and `ScrapIt/Core/DesignSystem/FilmSprocketStrip.swift` to match Figma `1717:68794` (remove `CreateRollHeaderDecoration`, update copywriting, placeholder, typography, `TextField` dimensions/radius, full-width `FilmStripShotSelector` with edge-to-edge sprocket holes, and Dark-Mode-safe `Color.black` / light toolbar scheme) while keeping the native Liquid Glass back button and `DSButton` `"Next"`.
- [x] Update `ScrapIt/Features/Roll/JoinRollView.swift` to match Figma `1663:46361` by horizontally centering the `319` pt `Enter code` + 6-box block beneath `"Turn on AirDrop to accept the invite"` with `"Enter code"` left-aligned to the boxes' leading edge across device widths, using `Color.black` and `.toolbarColorScheme(.light, for: .navigationBar)` for Dark Mode, while keeping the native Liquid Glass back button and `DSButton` `"Join Roll"`.
- [x] Run relevant unit tests / build check (`xcodebuild test`) and verify layout visually on iPhone (and iPad) sizes (50 tests in `RollRoomTests` passed on `iPhone Air` simulator; verified by user).

## Out of scope
- Editing `EditRollSetupView.swift`, `CreateRollFilterView.swift`, `CreateRollLobbyView.swift`, or `RollFlowViewModel.swift` logic/validation.
- Changing `DSButton` / `DSButtonStyle` or replacing the native Liquid Glass toolbar back button.
- Deleting `CreateRollHeaderDecoration` from `Assets.xcassets`.
- Editing main `spec/*.md` files before `/merge-change`.
