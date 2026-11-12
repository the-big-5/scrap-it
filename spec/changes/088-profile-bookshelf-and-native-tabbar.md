# 088: Profile Bookshelf, Empty-State Layout Fix, Profile Settings, and Native Tab Bar
Status: Done

## Why
1. **Empty Profile Layout Bug:** In `ProfileView`, `.background(DSColor.Kraft.lightActive.color.ignoresSafeArea())` sits directly on a `ScrollView` whose content lacks `.frame(maxWidth: .infinity)`. When `scrapbooks.isEmpty`, the `ScrollView` shrinks horizontally to the width of the empty-state text, leaving white vertical bars on the left and right edges on all iPhone sizes (verified on iPhone 16 Pro Max and iPhone 13 Mini).
2. **New Figma Designs & Flows (`1300:36485`, `1300:36434`, `1300:36781`):**
   - Replaces the temporary 2-column scrapbook cover grid with the Figma **wooden bookshelf** displaying up to 12 vertical book spines per shelf.
   - Replaces the empty-state caption with `"Your bookshelf is waiting!"`, a `"Create Roll"` button routing directly to `CreateRollSetupView`, and an empty wooden shelf.
   - Replaces the inline pencil icon beside the display name with a top-right circular `"⋯"` menu (`Profile Settings` and a non-implemented `Share Profile` stub).
   - Updates `EditProfileView` to **Profile Settings** (`"Profile Settings"` title and solid dark-red `"Log Out"` pill).
   - Replaces the custom `FloatingTabBarView` with SwiftUI's native `TabView` (`"Craft"` and `"Library"`).

## Touches
flows.md (F1 sign-out copy, F4 Profile bookshelf & Create Roll entry), ui.md (Home/Root native TabView, Profile/Library tab, Profile Settings), tech.md (Code structure, `Assets.xcassets/Profile/`)

## Changes
- MODIFIED `ScrapIt/App/MainShellView.swift`:
  - Replace custom `FloatingTabBarView` with SwiftUI native `TabView(selection: $router.selectedTab)`:
    - `Tab("Craft", systemImage: "camera.fill", value: AppTab.home)` rendering `WorkbenchView`
    - `Tab("Library", systemImage: "books.vertical.fill", value: AppTab.profile)` rendering `ProfileView`
  - Style active tab tint with `DSColor.Kraft.darker.color` and control bar visibility during the Workbench camera overlay using `.toolbarVisibility(router.shouldShowTabBar ? .visible : .hidden, for: .tabBar)`.
  - Remove `FloatingTabBarView` from the view hierarchy (confirm at implementation/merge whether to keep or delete `FloatingTabBarView.swift` and `TabBarDragMathTests` per `tech.md`'s `Do not delete files` rule).
- ADDED `ScrapIt/Assets.xcassets/Profile/`:
  - Wooden shelf plank PNG (`1515:31687` / `1300:36435`) and Figma book spine artwork/SVG masks downloaded from Figma (no temporary Figma asset URLs in code).
- MODIFIED `ScrapIt/Features/Profile/ProfileView.swift` & `ProfileViewModel.swift` (plus extracted bookshelf component(s) under `Features/Profile/Components/`):
  - **Full-Width Background:** Wrap `ProfileView` in a `ZStack` with `DSColor.Kraft.lightActive.color.ignoresSafeArea()` and apply `.frame(maxWidth: .infinity)` to `ScrollView` content so there are never white side gaps on empty or narrow layouts.
  - **Header & Top-Right `"⋯"` Menu:**
    - Remove the inline `pencil` button next to the user's name.
    - Keep the `120` pt circular `ProfileAvatarView`, centered `20` pt Bold name, and centered `13` pt italic bio (`"No bio yet"` when empty).
    - Add a top-right circular `"⋯"` `Menu` (`CircleIconLabel(systemName: "ellipsis")`) with:
      - `"Profile Settings"` (`gear`) → calls `viewModel.openProfileSettings()` (pushes `AppRoute.editProfile`).
      - `"Share Profile"` (`square.and.arrow.up`) → shown disabled / no-op `[Open]` for now (not implemented).
  - **Empty State (`1300:36485`):**
    - Show `"Your bookshelf is waiting!"` (`15` pt Medium), a `"Create Roll"` primary pill button (`Brand.primary` fill, `Paper.lightHover` `22` pt Bold text, width `217`, height `52`) pushing directly to `AppRoute.createRollSetup`, and the wooden shelf plank underneath.
  - **Bookshelf (`1300:36434`):**
    - Group `viewModel.scrapbooks` into rows of up to **12** vertical book spines standing on the wooden shelf plank image.
    - Cycle deterministically across the **12 Figma spine colors** (matching light/dark contrast for the `-90°`-rotated `Architects Daughter` scrapbook title on each spine).
    - Tap spine → `viewModel.open(scrapbook)`.
    - Long-press spine → `.contextMenu` `"Delete"` (destructive) → existing `"Delete this scrapbook?"` confirmation dialog.
- MODIFIED `ScrapIt/Features/Profile/EditProfileView.swift`:
  - Update top bar title from `"Edit Profile"` to `"Profile Settings"`.
  - Match the bottom `"Log Out"` button to Figma `1515:29898`: solid dark-red pill (`#681111` fill, `DSColor.Kraft.light` `#FCFBF9` `18` pt Semibold text, height `52`), preserving the existing sign-out confirmation alert.

## Tasks
- [x] Download Figma wooden shelf plank and book spine artwork into `Assets.xcassets/Profile/` and extract the exact 12-spine color palette
- [x] Replace `FloatingTabBarView` with SwiftUI native `TabView` (`"Craft"` `camera.fill` and `"Library"` `books.vertical.fill`, `.tint(DSColor.Kraft.darker.color)`, `.toolbarVisibility` synced to `router.shouldShowTabBar`) in `MainShellView.swift`
- [x] Fix `ProfileView` background with a root `ZStack` (`DSColor.Kraft.lightActive.color.ignoresSafeArea()`) + `.frame(maxWidth: .infinity)` on `ScrollView` content, remove inline `pencil` button, and add top-right `"⋯"` menu (`Profile Settings` + disabled `"Share Profile"` stub)
- [x] Implement `ProfileEmpty` state (`"Your bookshelf is waiting!"`, `"Create Roll"` → `AppRoute.createRollSetup`, wooden shelf plank) in `ProfileView` and `ProfileViewModel`
- [x] Implement wooden bookshelf rows (12 spines per shelf, deterministic 12-color Figma palette + rotated `Architects Daughter` title, tap to open, long-press context menu delete)
- [x] Update `EditProfileView` to `"Profile Settings"` title and solid `#681111` `"Log Out"` pill
- [x] Add/update unit tests in `ScrapItTests/Profile/ProfileViewModelTests.swift` (shelf grouping into 12-book rows, deterministic spine styling, `createRollSetup` routing, settings routing) and verify all tests pass on iOS Simulator

## Out of scope
- Implementing `"Share Profile"` behavior or profile deep links
- User-customizable book cover/spine colors (deferred; uses deterministic 12-color palette)
- Changing `WorkbenchView` layout or roll capture/editor flows
- Modifying `.xcodeproj` settings, signing, or entitlements
