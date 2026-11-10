# 043: Remove Explore Pages and Explore TabView
Status: Done

## Why
The Explore tab and `ExploreView` are currently a placeholder screen (`Discover shared rolls and inspiration soon.`) for future social discovery, which is still `[Draft]` / `[Open]` in the spec. Removing the Explore tab and page keeps the floating navigation bar focused on the two implemented root tabs (`Home` and `Profile`).

## Touches
ui.md (Home — floating navigation bar), tech.md (Code structure)

## Changes
- REMOVED `ScrapIt/Features/Explore/ExploreView.swift` and the empty `ScrapIt/Features/Explore/` folder (user confirmed file deletion for this change).
- MODIFIED `ScrapIt/App/Navigation/NavigationRoutes.swift`:
  - Remove `case explore` from `AppTab`, leaving `.home` and `.profile`.
- MODIFIED `ScrapIt/App/MainShellView.swift`:
  - Remove `case .explore: ExploreView()` from the `router.selectedTab` switch.
- MODIFIED `ScrapIt/App/FloatingTabBarView.swift`:
  - Remove `(.explore, "magnifyingglass", "Explore")` from `tabs`, leaving `.home` and `.profile`.
  - Shrink `barWidth` proportionally from `274` to `186` so each of the 2 tabs keeps `87` pt width (`(186 - 12) / 2`) around the `78×44` selection pill (`padding: 6`, `barHeight: 62`).
- MODIFIED `ScrapItTests/Home/WorkbenchLayoutTests.swift`:
  - Update `TabBarDragMathTests` to `TabBarDragMath(barWidth: 186, horizontalPadding: 6, tabCount: 2)` and verify 2-tab hit testing, clamping, pill tracking, and symmetric tab centers.
- Specs at merge (`/merge-change`):
  - `ui.md`: update the Home floating navigation bar line from 3 tabs (Home, Explore, Profile) to 2 tabs (Home `house.fill`, Profile `person.fill`).
  - `tech.md`: remove `Explore/        ExploreView (3-tab placeholder)` from the Code structure tree.

## Tasks
- [x] Delete `ScrapIt/Features/Explore/ExploreView.swift` and remove the empty `ScrapIt/Features/Explore/` folder
- [x] Remove `case explore` from `AppTab` in `ScrapIt/App/Navigation/NavigationRoutes.swift`
- [x] Remove `case .explore` from `MainShellView` in `ScrapIt/App/MainShellView.swift`
- [x] Remove the Explore tab item and update `barWidth` to `186` in `ScrapIt/App/FloatingTabBarView.swift`
- [x] Update `TabBarDragMathTests` in `ScrapItTests/Home/WorkbenchLayoutTests.swift` for `tabCount: 2` and `barWidth: 186`
- [ ] Build and run the unit test suite on iOS Simulator to confirm everything compiles and all tests pass

## Out of scope
- Removing or modifying `Social discovery [Draft]`, `Q3` in `spec/product.md`, or `F6: Social discovery [Open]` in `spec/flows.md`
- Redesigning `FloatingTabBarView` height, padding, pill size, colors, shadow, or drag/haptic behavior
- Modifying `WorkbenchView`, `ProfileView`, `AppRouter`, or `Navigator`
- Modifying `.xcodeproj` / `project.xcproj`

## Implementation findings
- Build succeeds on iOS Simulator (`iPhone 18 Pro`, iOS 27.2), and `TabBarDragMathTests` (4 tests) and `CameraBehaviorTests` (37 tests) pass in isolated runs.
- Full-suite `xcodebuild test` fails with exit code 65 due to a pre-existing SwiftData teardown crash (`SwiftData/BackingData.swift:941: Fatal error: This model instance was destroyed by calling ModelContext.reset and is no longer usable` on `CaptureSession`) immediately after `OptimisticShutterSlotClaimTests` finishes, which aborts the test host and flags `CameraBehaviorTests.filteredMovieCarriesSameContentIdentifier()`.
