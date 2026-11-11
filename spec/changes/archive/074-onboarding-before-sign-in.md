# 074: Onboarding Before Sign-In
Status: Done

## Why
Currently (change 053), onboarding slides are shown once after a successful sign-in before navigating to Home.
We need to change the sequence so onboarding slides appear on app startup when not signed in, before showing the Welcome / Sign-In screen.
When completing onboarding ("Let's Try It" on slide 3), the user transitions to the Welcome screen.
After signing in from Welcome, the user navigates directly to Home.
Upon sign-out, onboarding slides appear again before returning to Welcome.
If a user is already signed in on app launch (session restored), they bypass onboarding and go directly to Home.

User decisions:
- Shown once on app startup when not signed in before showing Welcome.
- Slide 3 button title is "Let's Try It" and transitions to Welcome with a smooth crossfade.
- After sign-in, user goes straight to Home.
- Signing out resets state and shows onboarding slides again.
- Tracked via in-memory state in `RootView`.

## Touches
flows.md (F1: Sign in), ui.md (Screen: Welcome / Sign in, Screen: Onboarding Slides)

## Changes
- MODIFIED `ScrapIt/App/RootView.swift`:
  - Show `OnboardingSlidesView` on startup when unauthenticated and onboarding is not yet completed for this session.
  - Tapping "Let's Try It" completes onboarding for this session and smoothly transitions to `WelcomeSignInView` with an opacity crossfade.
  - Successful sign-in from `WelcomeSignInView` routes directly to `MainShellView`.
  - Signing out resets onboarding completion state to re-present onboarding slides before `WelcomeSignInView`.
  - Session restoration on launch continues directly to `MainShellView` when authenticated.
- MODIFIED `ScrapIt/Features/Auth/OnboardingSlidesView.swift`:
  - Fix button title typo on slide 3 to "Let's Try It".
- MODIFIED `flows.md` (F1: Sign in):
  - Update flow to state unauthenticated users see onboarding slides on launch before Welcome, and navigate directly to Home after sign-in.
- MODIFIED `ui.md` (Screen: Onboarding Slides):
  - Update description to reflect presentation before sign-in instead of after.

## Tasks
- [x] Update `RootView.swift` to present `OnboardingSlidesView` before `WelcomeSignInView` when unauthenticated.
- [x] Route directly to `MainShellView` upon successful sign-in.
- [x] Re-trigger onboarding slides upon user sign-out.
- [x] Preserve direct routing to `MainShellView` for restored authenticated sessions.
- [x] Update unit tests in `ScrapItTests` to verify pre-sign-in onboarding flow and state transitions.
- [x] Verify test suite passes without regressions.

## Out of scope
- Modifying onboarding slide visual design, layouts, or assets.
- Changing slide copy or button labels.
- Persisting onboarding completion across app restarts in UserDefaults.
- Modifying Apple Sign-In authentication mechanism.
