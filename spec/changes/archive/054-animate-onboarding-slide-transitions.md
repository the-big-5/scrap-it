# 054: Animate Onboarding Slide Transitions
Status: Done

## Why
Currently, onboarding slides transition using a standard SwiftUI `TabView(.page)` horizontal slide with flattened illustration PNGs.
To deliver a delightful and tactile experience aligned with the Spark reference design (`Spark Onboarding Card Shuffle`), individual elements across slides 1, 2, and 3 must animate independently during slide transitions:
- Central illustration cards shuffle, tilt, and scale with playful spring physics.
- Peripheral elements (stars, film canisters, scissors, badges) perform a 3D flip and translate to new coordinates.
- Typography crossfades smoothly in sync with the slide transition.
- Slide navigation supports both tapping "Continue" / "Let's Try It" with spring animation and interactive horizontal drag scrubbing.

User decisions:
- Export individual element layers from Figma nodes `1248:21648` (OB1), `1249:22041` (OB2), and `1255:22152` (OB3) into `Assets.xcassets/Onboarding/`.
- No continuous ambient or idle floating loops while resting on a slide; playful shuffle animation occurs solely during slide transitions.
- Interactive horizontal drag scrubbing supported between slides.
- Custom layered coordinator view replaces `TabView(.page)` to prevent clipping and enable custom card shuffle and 3D flip effects.

## Touches
- `flows.md` (F1: Sign in)
- `ui.md` (Screen: Onboarding Slides)
- `ScrapIt/Features/Auth/OnboardingSlidesView.swift`
- `ScrapIt/Assets.xcassets/Onboarding/`

## Changes
- ADDED assets to `ScrapIt/Assets.xcassets/Onboarding/`:
  - Slide 1: Camera body, film canisters (200 and 400), film ribbons, 3 star characters.
  - Slide 2: Notebook, scissors, pencil, ruler, photo prints, starburst.
  - Slide 3: Books stack, 3 star characters, sparkles.
- MODIFIED `ScrapIt/Features/Auth/OnboardingSlidesView.swift`:
  - Replace `TabView(.page)` with a custom interactive container driven by slide index and horizontal drag gesture translation.
  - Render individual element layers with dynamic rotation, scale, offset, and 3D rotation transformations driven by slide progress.
  - Provide card shuffle motion with spring damping on button tap or gesture release past the swipe threshold.
  - Synchronize page indicator dot selection and primary button action ("Continue" vs "Let's Try It").
- MODIFIED `spec/ui.md`:
  - Document the animated card shuffle transitions and individual element composition for the Onboarding Slides screen.

## Tasks
- [x] Export individual layer assets from Figma nodes `1248:21648`, `1249:22041`, and `1255:22152` into `ScrapIt/Assets.xcassets/Onboarding/`.
- [x] Refactor `OnboardingSlidesView.swift` to replace `TabView` with a custom layered container supporting interactive drag scrubbing and animated button transitions.
- [x] Implement card shuffle and rotation transformations for the central elements with spring physics.
- [x] Implement 3D flip and position transitions for peripheral decorative elements (stars, tools, badges).
- [x] Ensure titles, descriptions, page indicator dots, and primary button labels animate smoothly across slides.
- [x] Preserve completion callback and button styling on slide 3 ("Let's Try It").
- [x] Update and expand unit tests in `ScrapItTests` to verify slide navigation, drag threshold snapping, and completion callbacks.
- [x] Verify build and tests pass without regressions on iOS Simulator.

## Out of scope
- Continuous ambient or idle floating animation loops while static on a slide.
- Adding a skip button or changing onboarding text copy.
- Altering the pre-sign-in presentation lifecycle in `RootView.swift`.
