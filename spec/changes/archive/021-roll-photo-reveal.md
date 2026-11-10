# 021: Roll photo reveal (envelope, tear, scattered photos, Tidy Up, photo detail)
Status: Done

## Why
After End Roll the app jumps straight into the scrapbook editor (change 013, "temporary until the design flow"). The design adds a reveal moment first: the roll arrives as a closed envelope, the user tears it open, the photos spill onto a cutting mat, and the user can look at, save and share them before starting the scrapbook.

## Touches
flows.md (F3 step 10, F5 step 1), ui.md (new Roll Reveal screen)

## Changes
- MODIFIED F3 step 10: when a roll ends, everyone (host and participants) sees the Roll Reveal screen. "Start Scrapbook" then opens the scrapbook editor (013, unchanged)
- ADDED Roll Reveal screen, shown **only once, right after End Roll** (no way back to it later; Profile still opens the editor)
  - Envelope (Figma 1323:41568): green cutting mat, closed kraft envelope with a paper label: roll name and "N photos" (the photos on this phone at that moment, no "/24" or "/36"), font Architects Daughter (design system)
  - Tear (1323:41482): swipe across the top of the envelope → the top strip tears off and the photos come out and scatter over the mat, slightly rotated and overlapping. Photos can be dragged around; a dragged photo comes to the front
  - "Tidy Up" (top right) → 2-column grid of all photos (793:3352, grid part only), scrolls down; each photo shows its capture time (e.g. "16:45"). Can switch back to the scattered photos
  - "Start Scrapbook" (bottom) on both views → scrapbook editor
  - Photo detail (1444:23620): tap a photo (scattered or grid) → it opens large with a white border over the dimmed mat; "Save" saves it to Photos (a Live Photo as a Live Photo); the share button opens the system share sheet; tap outside the photo closes it
- ADDED Photos permission (add-only, `NSPhotoLibraryAddUsageDescription`), asked on the first Save

## Tasks
- [x] Download the envelope / cutting-mat assets from Figma (read-only) into `Assets.xcassets`
- [x] `RollRevealViewModel` (no SwiftUI import): photos of the roll, label text, torn state, scatter layout (positions, rotation, order), drag / bring to front, Tidy Up toggle, grid order by capture time, selected photo, Save (Photos service) and Share
- [x] Photos save service (Core/Services): still or Live Photo (photo + movie) into the library, short success / failure message
- [x] `RollRevealView` + components: envelope with swipe-to-tear, scattered photos, grid, photo detail
- [x] Route: End Roll → Roll Reveal (new route in the app shell) → Start Scrapbook → editor
- [x] Photos add permission text (project setting — needs the user's OK, `.xcodeproj` exception)
- [x] Tests (Swift Testing): label ("1 photo" / "N photos"), scatter layout stays inside the screen, drag brings to front, Tidy Up toggle, grid sorted by time, Start Scrapbook routes to the editor, reveal is not shown again
- [x] Build and run all tests on Simulator
- [x] Manual check on iPhone: End Roll → envelope → swipe tears it → photos scatter and drag; Tidy Up ↔ scattered; tap → detail, Save (also a Live Photo), Share, tap outside closes; Start Scrapbook → editor — user confirmed on iPhone; the count first lagged (2 s polling, fixed with `ModelContext.didSave`), a small delay from the fetch remains [Open]

## Out of scope
- Header of 793:3352 (cover photo, title card, friends / shots stats, X, "⋯") and the "All Photos" filter
- Faster photo upload / download (change 020)
- Reopening the reveal later, editing or deleting photos here

## Open (proposals accepted with the approval)
- Photos that arrive after the envelope appears: proposal — the count on the label updates until the envelope is torn; photos arriving after that are dropped onto the mat / added to the grid
- The button to go back from the grid to the scattered photos: the grid design has no button for it. Proposal — the same top-right button, labeled "Scatter"
- Photo detail of a Live Photo: proposal — it plays (as on the scrapbook grid, change 012); Share sends the still photo
- Tear animation: there is no frame for the moment in between. Proposal — the top strip follows the finger and flies off, then the photos slide out of the envelope and spread over the mat; the envelope fades away. Haptic on tear

## Implementation findings
- Route `AppRoute.rollReveal(UUID)` (not a roll route); `RollFlowViewModel.finalizeSessionAndOpenScrapbook` now opens it instead of the editor; `MainShellView` maps it to `RollRevealView`. "Start Scrapbook" calls `setStack([.scrapbook(id)])`, so the reveal is not in the back stack and cannot be reopened
- `Features/Reveal/RollRevealViewModel.swift`: stage (envelope / scattered / tidy), photos read by the scrapbook's roll (`sourceSessionID`) and read again on every store save (`observePhotos`, `ModelContext.didSave`; first version polled every 2 s and the count lagged on device, user report), label "1 photo" / "N photos", scatter layout (3 jittered columns in a shuffled order, ±14°, long side 150 pt, repeatable with a seeded generator, centers kept between 110 pt from the top and 120 pt from the bottom), stack order / bring to front, move with clamping, Tidy Up ↔ Scatter, grid oldest first with "HH:mm", select / close, Save, Start Scrapbook. No SwiftUI import
- `Core/Services/PhotoLibrarySaver.swift` (`PhotoLibrarySaving`): add-only Photos access, `PHAssetCreationRequest` with `.photo` + `.pairedVideo` for Live Photos. Messages: "Saved to Photos" / "Couldn't save. Allow ScrapIt to add photos in Settings." (short toast at the top)
- Views: `RollRevealView`, `Components/RevealEnvelopeView` (layers + label; the top 49 pt flap strip follows the finger and flies off after 110 pt or a fast swipe; heavy haptic), `Components/RevealPhotoViews` (`RevealPhotoImage`, `RevealScatteredPhoto`, `RevealGridPhoto`, `RevealPhotoDetail` with `LivePhotoPlayerView` and `ShareLink` of the still photo)
- Assets (`Assets.xcassets/Reveal/`, read-only from Figma): `RevealCuttingMat@3x.png` (export of 1323:41569) and 7 envelope SVG layers (`EnvelopeBody`, `EnvelopeTextureA/B`, `EnvelopeFlap`, `EnvelopeFlapLine`, `EnvelopeLeftEdge`, `EnvelopeBottomFold`). The body's SVG drop shadow is ignored by iOS, but Figma clips it with the envelope frame anyway, so the envelope looks the same
- Mat color: Figma uses teal (#2C7657) on 1323:41568 and 1444:23620 but olive (#55834F) on 1323:41482. The teal mat is used for all stages (one mat, no color jump after the tear) — confirm with design
- Tidy Up grid background is Kraft light-active (#F7F2EB, as in 793:3352)
- Photos permission text added to `ScrapIt-Info.plist` (repo root, merged into the generated Info.plist since change 011) instead of the `.xcodeproj`: "Save photos from your roll to Photos"
- Tests: `ScrapItTests/Reveal/RollRevealTests.swift` (9). `RollRealtimeServiceTests` expects `.rollReveal` after the last slot. Full suite: 219 tests in 22 suites pass, 1 known issue (toggle contrast, 003)
- Layout checked by rendering the screen to images on the Simulator (envelope with short and long roll names, scattered photos, detail) through a temporary test that was removed afterwards. Tear animation, drag, Live Photo playback, Save and Share need the device check

