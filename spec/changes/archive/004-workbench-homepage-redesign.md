# 004: Workbench Homepage Redesign & 3-Tab Bar
Status: Done

## Why
The homepage design changed from a vertical shelf to an overhead workbench / cutting-mat flat-lay (Figma node `853:1703`). Tapping the disposable camera presents an interactive "Create Roll" and "Join a Roll" menu (Figma node `984:3163`). The app navigation transitions from a floating 2-tab bar to a 3-tab layout styled using native iOS `TabView`.

## Touches
ui.md (Home screen redesigned to Workbench; Tab bar updated to 3 tabs), flows.md (Home navigation & Camera Roll trigger), tech.md (AppTab enum updated to 3 tabs)

## Changes
- ADDED: Assets for workbench flat-lay (wood/leather desk surface, cutting mat, disposable camera, stacked books, film rolls, ruler, stationery elements) in `Assets.xcassets`.
- RENAMED / REFACTORED: `ShelfView.swift` (`ShelfView`) and `ShelfViewModel.swift` (`ShelfViewModel`) renamed to `WorkbenchView.swift` (`WorkbenchView`) and `WorkbenchViewModel.swift` (`WorkbenchViewModel`) in `Features/Home/` to reflect the new workbench metaphor.
- REPLACED: Obsolete shelf illustration components in `Features/Home/Components/` (`WoodenShelfPlank.swift`, `HangingLampIllustration.swift`, `LampLightConeShape.swift`, `CatFigurineIllustration.swift`, `PottedPlantIllustration.swift`, `StickerCaddyIllustration.swift`, `ShelfBooksCluster.swift`, `ShelfFilmCanistersCluster.swift`) replaced with Workbench components (`CuttingMatView.swift`, `DisposableCameraView.swift`, `DeskDecorationsView.swift`, `DeskMeasuringRulerView.swift`, `DeskWoodBackgroundView.swift`).
- MODIFIED: Camera tap interaction matching Figma node `984:3163` (`CameraClik`): tapping the disposable camera dims the desk and presents "Create Roll" and "Join a Roll" action buttons.
- MODIFIED: `AppTab` in `Core/Services/Navigator.swift` to support 3 tabs: `.home`, `.explore` (stubbed search/explore tab), and `.profile`.
- MODIFIED: `MainTabView.swift` to use native SwiftUI `TabView(selection:)` with customized tab bar appearance (via `UITabBarAppearance` / SwiftUI toolbar styling) matching the Figma tab bar design.
- REMOVED: `FloatingHomeProfileTabBar.swift` in `App/` (superseded by native TabView styling) and obsolete shelf image assets in `Assets.xcassets`.

## Tasks
- [x] Pull and import workbench assets from Figma nodes `853:1703` and `984:3163` into `Assets.xcassets` (`@1x`, `@2x`, `@3x`)
- [x] Remove obsolete shelf image assets from `Assets.xcassets`
- [x] Update `AppTab` enum in `Core/Services/Navigator.swift` to 3 tabs (`home`, `explore`, `profile`)
- [x] Update `MainTabView.swift` to native `TabView` styled with custom appearance (tint, background blur/material, icons `house.fill`, `magnifyingglass`, `person.fill`)
- [x] Remove `FloatingHomeProfileTabBar.swift`
- [x] Rename `ShelfViewModel.swift` to `WorkbenchViewModel.swift` (`WorkbenchViewModel`), updating dependencies in `MainTabView.swift`
- [x] Rename `ShelfView.swift` to `WorkbenchView.swift` (`WorkbenchView`) and build workbench components in `Features/Home/Components/` (`CuttingMatView.swift`, `DisposableCameraView.swift`, `DeskDecorationsView.swift`, etc.)
- [x] Remove old shelf component files from `Features/Home/Components/`
- [x] Implement camera tap state and popup overlay ("Create Roll", "Join a Roll") matching Figma node `984:3163`
- [x] Connect "Create Roll" and "Join a Roll" buttons to existing `RollFlowViewModel` navigation
- [x] Wire stacked books as an open stub for the upcoming tutorial flow
- [x] Run `xcodebuild` test/build and verify no regressions

## Out of scope
- Tutorial flow triggered by the stacked books (open, to be designed later)
- Completed scrapbook list on the Profile page (open, to be designed later)
- Search / explore functionality for the 2nd tab (placeholder view only)
- Changes to Roll flow steps or camera capture functionality
