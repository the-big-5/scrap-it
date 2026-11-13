# 142: Update Sign In UI
Status: Done

## Why
- `WelcomeSignInView` still displays the older placeholder layout from Figma `676:3703` (`"LOGO"` placeholder box, `"Shoot together. Keep it forever."` headline, subtext, and single `RetroCameraIllustration`), whereas the updated Sign In screen in Figma `1545:40827` replaces the header/text/camera with a centered craft collage illustration over `#F7F2EB` (`Kraft.lightActive`), paired with the bottom `"Sign in With Apple"` button and Terms/Privacy footnote.

## Touches
- `ui.md` (`Screen: Welcome / Sign in`, `Assets`)

## Changes
- MODIFIED `WelcomeSignInView` (`ScrapIt/Features/Auth/WelcomeSignInView.swift`, Figma `1545:40827`):
  - Use `DSColor.Kraft.lightActive` (`#F7F2EB`) background.
  - Remove the `"LOGO"` placeholder box, `"Shoot together. Keep it forever."` headline, `"Sign in to start a shared roll..."` subtext, and `RetroCameraIllustration`.
  - Add the centered craft collage illustration from Figma `1545:40827` (3 yellow star characters, disposable camera, yellow 200 film roll, spiral notebook, yellow ruler, orange starburst, and stacked photo cards, with Figma drop shadows on the camera and film roll).
  - Position the bottom `Actions` block (`22` pt horizontal padding, `16` pt spacing): `SignInWithAppleButton(.signIn)` (`black` capsule, `52–54` pt height, `0.5` opacity when offline, disabled when offline) and static footnote `"By continuing, you agree to our Terms of Use and Privacy Policy."` (`13` pt Regular `#5E5449` / `DSColor.Component.textSecondary`, with Semibold `#2A241F` / `DSColor.Brand.primary` for `Terms of Use` and `Privacy Policy`).
  - Keep `authViewModel.welcomeMessage` (error / offline message) above the button when present.
- ADDED / REUSED `Assets.xcassets`:
  - Inspect and compare each Figma `1545:40827` sprite (`1545:41111`..`1545:41126`) against existing `Assets.xcassets` assets (`ToolboxEmptyStarburst`, `RollEmptyStarTop`, `RollEmptyStarLeft`, `RollEmptyStarRight`, `DeskDisposableCamera`, `DeskFilmRollYellow`, `ToolboxEmptyNotebook`, `ToolboxEmptyRuler`, `ToolboxEmptyPhotoBack`, `ToolboxEmptyPhotoFront`).
  - Reuse existing assets wherever the artwork is identical (differing only in position, scale, or rotation); download and add new PNG/SVG imagesets only for any layer whose artwork differs even slightly from existing assets.

## Tasks
- [x] Download reference preview / SVG & PNG assets from Figma `1545:40827` (`1545:41111`..`1545:41126`), compare against existing assets in `ScrapIt/Assets.xcassets/`, reuse identical sprites, and add new SVG/PNG imagesets only for layers with visual differences.
- [x] Update `ScrapIt/Features/Auth/WelcomeSignInView.swift` to match Figma `1545:40827` (centered craft collage, removed LOGO/headline/subtext, updated `Actions` layout and `13` pt footnote, keeping `SignInWithAppleButton` auth logic and `authViewModel.welcomeMessage`).
- [x] Run build and unit tests (`xcodebuild test`) and verify layout visually on iPhone (and iPad) simulator sizes.

## Out of scope
- Changing `AuthViewModel` Sign in with Apple authentication flow, `OnboardingSlidesView`, or `RootView` navigation.
- Making `"Terms of Use"` or `"Privacy Policy"` interactive links/sheets.
- Deleting `HeroCamera` or `RetroCameraIllustration` if still referenced elsewhere or in previews/tests.
- Editing main `spec/*.md` files before `/merge-change`.
