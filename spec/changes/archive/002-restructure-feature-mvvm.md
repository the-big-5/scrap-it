# 002: Restructure to feature-first MVVM
Status: Done

## Why
The code was built as a flat `Views/`, `ViewModels/`, `Services/`, `Models/` layout, with logic mixed into Views and one large `RollFlowViewModel`. Move it to the structure and rules locked in tech.md ("Code structure") so future changes land in the right place.

## Touches
tech.md (Code structure), ui.md (no changes expected), flows.md (no changes expected)

## Changes
Pure refactor. Behavior, visuals, navigation and data must stay identical. No new features.

- MOVED: files into `App/`, `Core/` and `Features/` (see target layout below)
- SPLIT: `RollFlowViewModel` into per-feature ViewModels (one `@Observable` ViewModel per feature)
- MOVED: logic out of Views into the feature ViewModel (Views only render state and forward actions)
- MOVED: `CameraController` out of `CaptureSessionView.swift` into `Core/Services/`
- SPLIT: multi-view files into one file per type, shared pieces into `Core/DesignSystem/`
- RENAMED: `ContentView` to `RootView`; `HomeContainerView` split into `MainTabView` (App) and Home/Profile views

### Target layout
```text
ScrapIt/
├── App/
│   ├── ScrapIt.swift
│   ├── RootView.swift
│   └── MainTabView.swift
├── Core/
│   ├── Models/          (UserProfile, Scrapbook, ScrapPhoto, CaptureSession, RollFilter, SessionStatus)
│   ├── Services/        (CloudKitSessionService, CameraController)
│   └── DesignSystem/    (ScrapTheme, OffsetPillButtonStyle, BackCircleButton, RetroCameraIllustration,
│                         FilmSprocketStrip, ScrapDataImageView)
└── Features/
    ├── Auth/            (WelcomeSignInView, AuthViewModel)
    ├── Home/            (ShelfView, ShelfViewModel, Components/: lamp, plank, plant, sticker box, cat, books, canisters, light cone)
    ├── Profile/         (ProfileView, ProfileViewModel)
    ├── Roll/            (CameraRollMenuView, CreateRoll step views, JoinRollView, CaptureSessionView,
    │                     RollViewModel, Components/: film strip selector, canister rows, QR view, camera preview, grid overlay)
    └── Scrapbook/       (ScrapbookGridView, ScrapbookViewModel, Components/: photo card)
```

## Tasks
- [x] Create folders `App/`, `Core/{Models,Services,DesignSystem}`, `Features/{Auth,Home,Profile,Roll,Scrapbook}`
- [x] Move models into `Core/Models/`, one type per file
- [x] Move `CloudKitSessionService` into `Core/Services/`; extract `CameraController` into `Core/Services/`
- [x] Move theme and shared components into `Core/DesignSystem/`
- [x] Auth: move `WelcomeSignInView` and `AuthViewModel`; Views contain no logic
- [x] Home: `ShelfView` and `ShelfViewModel`; illustrations into `Components/`
- [x] Profile: `ProfileView` and `ProfileViewModel`
- [x] Roll: split `RollFlowViewModel` into `RollViewModel` (create, join, capture, end roll); move the roll Views; remove camera, session and host-menu logic from `CaptureSessionView` into the ViewModel
- [x] Scrapbook: `ScrapbookGridView` and `ScrapbookViewModel` (finalize session into scrapbook, caption saving)
- [x] App: `RootView` (sign-in vs Home routing), `MainTabView` (tab bar and navigation stack), keep deep link handling (`onOpenURL`)
- [x] ViewModels must not import SwiftUI; services are injected into ViewModels, not created in Views
- [x] After each move, run `xcodebuild` (iOS Simulator) and confirm `BUILD SUCCEEDED`
- [x] Final check: same screens, same navigation, same behavior as before

## Out of scope
- Any new feature, visual change or copy change
- Changing CloudKit behavior, data models or entitlements
- `.xcodeproj` settings, signing, entitlements
- Adding third-party libraries
- Updating spec files (merge step does that)
- Your next problem/feature (separate change)

## Decisions made during implementation
- Navigation: `Navigator` protocol + `AppRoute`/`AppTab` in `Core/Services`, `AppRouter` in `App/`. Feature ViewModels receive the navigator by injection.
- Shared state: `SessionStore` in `Core/Services` owns the active session and scrapbook, and creates the scrapbook when a roll ends.
- `RollFlowViewModel` keeps its name (and the `arr` / `yangBisaDiTest` members) so the existing `ScrapItTests` keeps compiling; it is not split further because the Roll feature has one ViewModel.
- `@Query` data sources stay in `MainTabView` and `ScrapbookGridView`; `ShelfView` takes closures.

## Open before approving (answered)
- Where navigation state (`RollRoute`, `AppTab`, `navigationPath`) lives: in `MainTabView` / a small `AppRouter` in `App/`, or inside feature ViewModels. Rule: no cross-feature imports, so cross-feature navigation needs one shared owner.
- Which ViewModel owns the "active session" and "active scrapbook" shared by Roll and Scrapbook (they must not import each other).
