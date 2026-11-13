# 134: Update App Name to Rèlic and Add App Icon
Status: Done

## Why
- The app's product name is changing from `ScrapIt` to **`Rèlic`**, which must apply consistently across the iOS/iPadOS Home Screen display name, share/invite copy (`AppBrand.name`), and user-facing permission error text (`RollRevealViewModel`).
- The app currently has no `AppIcon` in `Assets.xcassets`.

## Touches
- `ui.md` (`Share Room`, `Screen: Roll Reveal`, `Assets`)
- `tech.md` (`Code structure` / `AppBrand`, `.xcodeproj` exceptions, `Saving to Photos`)

## Changes
- MODIFIED `ScrapIt.xcodeproj/project.xcproj` & `ScrapIt-Info.plist`:
  - Set `INFOPLIST_KEY_CFBundleDisplayName` = `Rèlic` and `ASSETCATALOG_COMPILER_APPICON_NAME` = `AppIcon` in `ScrapIt.xcodeproj/project.xcproj` (approved `.xcodeproj` exception; Xcode also migrated `NSPhotoLibraryAddUsageDescription` from `ScrapIt-Info.plist` to `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription`).
- MODIFIED `ScrapIt/Core/Models/AppBrand.swift`:
  - Update `AppBrand.name` from `"ScrapIt"` to `"Rèlic"`.
- MODIFIED `ScrapIt/Features/Reveal/RollRevealViewModel.swift`:
  - Update `saveFailedMessage` to `"Couldn't save. Allow \(AppBrand.name) to add photos in Settings."` so it follows `AppBrand.name`.
- ADDED `ScrapIt/Assets.xcassets/AppIcon.appiconset/`:
  - Generate an opaque `1024×1024` PNG from the user-provided `Rèlic` film-and-scissors icon (flattening the transparent rounded corners onto the icon's cream background `#F9F5ED` so iOS and iPadOS do not render black corners when applying the system icon mask).
  - Configure `Contents.json` (`"idiom": "universal"`, `"platform": "ios"`, `"size": "1024x1024"`) to cover both **iPhone (iOS)** and **iPad (iPadOS)** icon sizes.
- MODIFIED `ScrapItTests/Roll/RollRoomTests.swift` (if needed) / add test check:
  - Verify `AppBrand.name == "Rèlic"` and existing `RollInviteShare` tests pass with the new name.

## Tasks
- [x] Add `CFBundleDisplayName` (`Rèlic`) to `ScrapIt-Info.plist` and `"ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon"` to `ScrapIt.xcodeproj/project.xcproj` (verified `"CFBundleDisplayName" => "Rèlic"`, `CFBundleIcons`, and `CFBundleIcons~ipad` in built `ScrapIt.app/Info.plist`)
- [x] Update `AppBrand.name` to `"Rèlic"` in `ScrapIt/Core/Models/AppBrand.swift`
- [x] Update `RollRevealViewModel.saveFailedMessage` in `ScrapIt/Features/Reveal/RollRevealViewModel.swift` to use `AppBrand.name`
- [x] Add `ScrapIt/Assets.xcassets/AppIcon.appiconset/` (opaque `1024×1024` PNG flattened onto `#F9F5ED`, universal iOS + iPadOS `Contents.json`)
- [ ] Verify build and unit tests pass on iPhone and iPad simulators (64 tests in `RollRoomTests` & `RollRevealTests` passed on iPhone simulator; iPad simulator run & visual Home Screen check pending)

## Out of scope
- Replacing the `"LOGO"` placeholder in `ScrapIt/Features/Auth/WelcomeSignInView.swift` (`AppLogo` will be handled separately later)
- Renaming the Xcode target, Swift module (`ScrapIt`), bundle identifier, CloudKit container/subsystem strings (`Logger`, `DispatchQueue`), or `Notification.Name`
- Adding alternate app icons or dark/tinted app icon variants (unless requested later)
- Updating main `spec/*.md` files before `/merge-change`
- Touching/committing personal `DEVELOPMENT_TEAM` / `PRODUCT_BUNDLE_IDENTIFIER` edits in `ScrapIt.xcodeproj/project.xcproj` or running any `git add`, `git commit`, or `git push`
