# 017: Real sample photos on the Choose Filter page, rendered with the app's filters
Status: Done

## Why
The film strips on "Choose a filter" show placeholder icons ("Friends", "Cafe", …). Figma 1187:8489 shows real photos. The user wants the samples to match the app's actual filters, so they are rendered by the same pipeline as the camera.

## Touches
ui.md (Create Roll Filter: Figma node 675:5759 → 1187:8489, samples), tech.md (Code structure), flows.md (none)

## Changes
- MODIFIED ui.md Create Roll Filter: Figma node **1187:8489** replaces 675:5759 (user decision)
- Each canister's film strip shows **4 sample photos**, horizontally scrollable (user decision)
- Samples are the user's original (unfiltered) photos, bundled small, and filtered **at runtime by `FilmFilterPipeline`** with that canister's look (B&W noir / Digicam from 016), so they always match the camera. Rendered off the main thread once and cached
- Behavior as today (user decision): only the **selected** canister's strip shows the photos; the other strip stays dark
- Photos (12 provided by the user), proposed split — 4 per filter, the rest not used:
  - B&W (Cinematic 400): cafe friends laughing, men cheering with beer, friends playing cards with pizza, girls on the canyon rock
  - Digicam (200 Color Print): friends at the beach, friends taking a selfie at the cafe, hikers' selfie at the waterfall, woman eating at the cafe
  - Not used: three friends with ice cream, friends hugging by the car, friends on the boat, table full of food
- License credit: not in this change (user decision, revisit later; see Open)
- Assets: originals downscaled to ~720 px long side, JPEG, in `Assets.xcassets/FilterSamples/` (originals are 10–18 MB each; the strip frames are 96 × 84 pt)

## Tasks
- [x] Downscale the 8 chosen photos and add them as assets (PascalCase names, no numbers in code names)
- [x] `FilterSamplePhotos` (which assets per `RollFilter`) and a sample renderer using `FilmFilterPipeline` + `RenderContext`, cached per filter
- [x] Filter page ViewModel exposes the rendered samples; `FilmCanisterFilterRow` shows them (aspect fill in the 96 × 84 frames), scrollable, only when selected; placeholder icons removed
- [x] Tests: 4 samples per filter, all assets load, rendered sample size / not nil, B&W sample is grayscale
- [x] Build and run all tests on Simulator
- [x] Manual check on iPhone: select each canister → its 4 photos appear, scroll, look matches the camera — user confirmed on iPhone ("sudah saya cek semua")

## Out of scope
- Changing the canisters, the page layout or the filters themselves (016)
- Showing samples on the unselected strip

## Open
- Photo licenses: the photos are from Freepik (user). A free Freepik license needs attribution (credit to Freepik / the author) where the photos are used; a Premium license does not. Which license applies, and where a credit would go (e.g. an About / Credits screen), is not decided yet. Skipped for now; the user will revisit it later (no credit in the app in this change). Options discussed: (a) small "Sample photos: Freepik" text on the Choose Filter page, (b) a Credits / About screen (new change), (c) App Store description as an extra. Check the license file that comes with the Freepik download; Premium needs no credit. The 8 used photos and their Freepik file names are listed in the Notes

## Notes
- Source files (Freepik, from the user's Downloads): B&W — cheerful-friends-sitting-cafe-eating-drinking-alcohol, cheerful-men-friends-sitting-cafe-while-drinking-beer, medium-shot-friends-eating-pizza, girls-smiling-sitting-rock-enjoying-view-canyon; Digicam — spending-hot-day-seashore, smiling-friends-cafe-drinking-alcohol-make-selfie, group-friends-having-fun-taking-selfies-nature, smiling-cheerful-asian-female-hand-hold-fish-chip-breakfast-while-enjoy-eating-laugh-conversation-with-her-friend-near-window-store-cafe-restaurant

## Implementation findings
- Assets: `Assets.xcassets/FilterSamples/` — 8 imagesets (`FilterSampleCafeFriends`, `FilterSampleBeerCheers`, `FilterSamplePizzaCards`, `FilterSampleCanyonRock` for B&W; `FilterSampleBeach`, `FilterSampleCafeSelfie`, `FilterSampleWaterfallSelfie`, `FilterSampleCafeEating` for Digicam), 720 px long side, JPEG quality 80, 924 KB in total (originals 10–18 MB each, not added)
- `Core/Services/FilterSamplePhotos.swift`: asset names per filter and `FilterSampleRenderer` (renders off the main thread with its own `FilmFilterPipeline` and the shared Metal `RenderContext`, preview path, cached per filter)
- `RollFlowViewModel.filterSamples` + `loadFilterSamples()` (called from the Choose Filter page's `.task`); `FilmCanisterFilterRow` takes the rendered images: 4 frames 96 × 84 pt, aspect fill, horizontal scroll, photos only on the selected strip (the other stays dark). Placeholder icons / gradients removed
- Only the strip changed; the rest of the page (header decoration, canisters, layout) is unchanged and was not compared with Figma 1187:8489
- Tests: `ScrapItTests/Roll/FilterSamplePhotosTests.swift` (4 samples per filter, all load and render at 720 px, different photos per filter, B&W grayscale, Digicam keeps color, ViewModel loads both). Full suite: 182 tests in 19 suites pass, 1 known issue (toggle contrast, 003)

