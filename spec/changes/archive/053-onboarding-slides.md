# 053: Onboarding Slides After Sign-In
Status: Done

## Why
Currently, upon successful sign-in from the Welcome screen, users immediately transition directly to `MainShellView` (Workbench). To onboard users into the product's core concepts—shared disposable rolls, collaborative scrapbooking, and bookshelf memories—three onboarding slides must be presented sequentially before navigating to the homepage.

Per design requirements from Figma:
- Slide 1 (OB1, Node 1248:21648): "A film camera experience. Shared with friends." / "Start a shared roll, take turns capturing your moment, and make every shot count." with button "Continue".
- Slide 2 (OB2, Node 1249:22041): "Turn your memories into scrapbook." / "Reveal your photos when the roll is complete, then create and decorate a scrapbook together." with button "Continue".
- Slide 3 (OB3, Node 1255:22152): "Make memories you can revisit." / "Keep your completed scrapbooks on your bookshelf and revisit the moments you made together." with button "Lets Try It".

User decisions:
- Appears on every sign-in from the Welcome screen.
- Navigation supports both horizontal paging swipe gestures and button taps ("Continue" advances, "Lets Try It" finishes).
- Strict Figma match: no skip button.

## Touches
- `flows.md` (F1: Sign in)
- `ui.md` (Screen: Onboarding Slides)
- `ScrapIt/App/RootView.swift`
- `ScrapIt/Features/Auth/OnboardingSlidesView.swift` (new)
- `ScrapIt/Assets.xcassets` (new onboarding collage assets)

## Changes
- ADDED `ScrapIt/Features/Auth/OnboardingSlidesView.swift`:
  - Three-slide horizontal paging view for OB1, OB2, and OB3.
  - Pixel-accurate layout and styling matching Figma: kraft background (`#f7f2eb`), seamless film strip backdrop, collage graphics, typography (SF Pro Bold 20pt title, SF Pro Regular 15pt description), and page control indicators.
  - Large Primary button ("Continue" on slides 1 & 2; "Lets Try It" on slide 3) with solid shadow styling.
  - Completion callback triggered when tapping "Lets Try It" on slide 3.
- ADDED Assets in `ScrapIt/Assets.xcassets/Onboarding/`:
  - Static visual collage assets extracted from Figma nodes `1248:21648`, `1249:22041`, and `1255:22152`.
- MODIFIED `ScrapIt/App/RootView.swift`:
  - Track state for onboarding presentation after sign-in.
  - When user signs in, present `OnboardingSlidesView` before transitioning to `MainShellView`.
  - When user completes onboarding ("Lets Try It"), navigate to `MainShellView`.
  - On sign out, reset state so onboarding appears upon the next sign-in.

## Tasks
- [x] Export and import static collage assets from Figma nodes `1248:21648`, `1249:22041`, and `1255:22152` into `Assets.xcassets/Onboarding/`.
- [x] Create `OnboardingSlidesView.swift` with exact Figma layout, typography, page control, and button styles for OB1, OB2, and OB3.
- [x] Wire slide progression to support both horizontal paging gestures and "Continue" / "Lets Try It" button taps.
- [x] Update `RootView.swift` to route through `OnboardingSlidesView` after sign-in before presenting `MainShellView`.
- [x] Add unit tests verifying onboarding state transitions and navigation completion in `ScrapItTests`.
- [x] Verify build and tests pass without regressions on iOS Simulator.

## Out of scope
- Skip button or dismissing onboarding prematurely before slide 3.
- Showing onboarding slides outside the sign-in flow (e.g. from Profile or Settings).
- Modifying authentication credential validation or Apple Sign-In services.
