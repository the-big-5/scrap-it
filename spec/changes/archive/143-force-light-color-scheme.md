# 143: Force Light Color Scheme Across App
Status: Done

## Why
- `DSColor` tokens already keep light values in Dark Mode (`dark == light`), and `spec/ui.md` notes `Dark mode: dark values equal light for now`.
- Views and system chrome using SwiftUI adaptive defaults (`Color.primary`, `Color.secondary`, `NavigationBar` titles, `TabView`, and sheets) turn white/light when the device is in Dark Mode, making text unreadable on warm cream/paper backgrounds (e.g., `ProfileView`, `EditProfileView`, `DeskCollectionView`, `DeskEmptyStateView`, `InviteFriendSheetView`, `ScrapbookBookView`, `CreateRollFilterView`, `EditRollSetupView`).
- Setting `.preferredColorScheme(.light)` at the app root (`RootView`) enforces Light Mode app-wide in one place so all text and navigation chrome remain black/dark ink without touching every view.

## Touches
- `ui.md` (`Design system` → `Colors`: `Dark mode`)

## Changes
- MODIFIED `ScrapIt/App/RootView.swift`:
  - Apply `.preferredColorScheme(.light)` to the root view body so onboarding, sign-in, `MainShellView`, pushed navigation screens, tab bar, sheets, and SwiftUI adaptive colors (`Color.primary` / `Color.secondary`) stay in Light Mode regardless of the device's Dark Mode setting.

## Tasks
- [x] Apply `.preferredColorScheme(.light)` in `ScrapIt/App/RootView.swift`.
- [x] Run build / unit tests (`xcodebuild test`) and verify visually in Dark Mode on simulator/device that text, navigation titles, and sheets remain dark over cream/paper backgrounds (379 tests in 31 suites passed on `iPhone Air` simulator with 1 pre-existing known issue; verified by user).

## Out of scope
- Refactoring individual `Color.primary` / `Color.secondary` usages across every feature view.
- Designing or supporting a Dark Mode theme.
- Editing `.xcodeproj` or `ScrapIt-Info.plist` (`UIUserInterfaceStyle`) unless needed later for out-of-SwiftUI UIKit presentations.
- Editing main `spec/*.md` files before `/merge-change`.
