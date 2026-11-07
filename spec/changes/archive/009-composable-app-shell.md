# 009: Composable App Shell and Navigation Refactor
Status: Done

## Why
The `App/` directory currently suffers from multiple structural anti-patterns:
1. `OrientationLock.swift` hides a top-level UIKit `AppDelegate` class in `App/` alongside screen rotation logic.
2. `MainTabView.swift` is a monolithic "God View" that eagerly instantiates and retains ViewModels for every feature (`RollFlowViewModel`, `WorkbenchViewModel`, `ProfileViewModel`, `ScrapbookViewModel`) in `@State` for the app's entire lifetime.
3. `MainTabView.swift` queries domain data via `@Query(sort: \Scrapbook.createdDate)` and manually passes it into child views.
4. Navigation state and route definitions are scattered instead of organized under `App/Navigation/`.
5. Deep link handling (`.onOpenURL`) is hardcoded directly into `rollViewModel` inside the shell view.

Fix: Refactor `App/` to match the composable target structure:
```text
ScrapIt/App/
├── ScrapIt.swift             # Pure @main entry point: SwiftData container + RootView
├── AppDelegate.swift         # Clean UIKit delegate for lifecycle & orientation
├── RootView.swift            # Clean Auth gate: Splash vs Welcome vs Shell
├── MainShellView.swift       # Lightweight tab switcher + FloatingTabBarView (NO @Query, NO feature ViewModels)
├── FloatingTabBarView.swift  # Dumb tab bar UI
└── Navigation/
    ├── AppRouter.swift       # Handles tab state + deep link URL parsing
    └── NavigationRoutes.swift# Clean route definitions
```

## Touches
tech.md (Code structure / App folder and ViewModel ownership)

## Changes
- ADDED `App/AppDelegate.swift`:
  - Dedicated file for `AppDelegate: NSObject, UIApplicationDelegate` delegating orientation mask to `OrientationLock`.
- MOVED `App/OrientationLock.swift` → `Core/Services/OrientationLock.swift`:
  - Houses `OrientationLock` in `Core/Services/` with `AppDelegate` removed.
- ADDED `App/Navigation/NavigationRoutes.swift` & MOVED `App/AppRouter.swift` → `App/Navigation/AppRouter.swift`:
  - Organizes route definitions (`AppTab`, `AppRoute`) and `AppRouter` under `App/Navigation/`.
  - `AppRouter` manages `selectedTab`, `path`, `isTabBarHidden`, and `handle(url:)`.
- RENAMED / REPLACED `App/MainTabView.swift` → `App/MainShellView.swift`:
  - Lightweight tab switcher + `FloatingTabBarView` with **NO `@Query`** and **NO feature ViewModels** stored in `@State`.
  - Owns only `AppRouter` and `SessionStore`, delegating ViewModel creation and data fetching to each feature.
- MODIFIED `Features/Home/WorkbenchView.swift` & `WorkbenchViewModel.swift`:
  - `WorkbenchView` owns its `WorkbenchViewModel` (initialized with `modelContext`, `navigator`, `sessionStore`).
  - `WorkbenchViewModel` fetches its own scrapbooks via `modelContext` and updates `navigator?.isTabBarHidden` when the camera overlay is active.
- MODIFIED `Features/Profile/ProfileView.swift` & `ProfileViewModel.swift`:
  - `ProfileView` owns its `ProfileViewModel` (initialized with `modelContext`, `currentUser`).
  - `ProfileViewModel` fetches its own scrapbook count via `modelContext`.
- MODIFIED `Features/Scrapbook/ScrapbookGridView.swift`:
  - Owns its `ScrapbookViewModel` (initialized with `modelContext`, `navigator`, `sessionStore`).
- MODIFIED `Features/Roll/`:
  - Roll flow screens share a flow-scoped `RollFlowViewModel` alive only while a Roll route is active on the navigation stack.

## Tasks
- [x] Move `OrientationLock` to `Core/Services/OrientationLock.swift` and keep only `AppDelegate` in `App/AppDelegate.swift`
- [x] Create `App/Navigation/NavigationRoutes.swift` and move `AppRouter` to `App/Navigation/AppRouter.swift` with URL handling (`handle(url:)`) and `isTabBarHidden`
- [x] Update `WorkbenchViewModel` and `WorkbenchView` so the feature owns its ViewModel and fetches its own scrapbooks via `modelContext`
- [x] Update `ProfileViewModel` and `ProfileView` so the feature owns its ViewModel and fetches its own scrapbook count via `modelContext`
- [x] Update `ScrapbookGridView` and Roll flow routing so feature ViewModels are scoped to their features rather than held on the app shell
- [x] Replace `MainTabView.swift` with `MainShellView.swift` (pure tab switcher + `FloatingTabBarView`, no `@Query`, no feature `@State` ViewModels) and update `RootView.swift`
- [x] Update unit tests in `ScrapItTests`
- [x] Build and verify all unit tests pass on iOS Simulator

## Out of scope
- Visual redesign or styling changes to `FloatingTabBarView` or workbench desk assets
- Altering existing user flows (F1 through F5)
- Changing SwiftData models or schema definitions
