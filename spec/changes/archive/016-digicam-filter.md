# 016: "Digicam" look for the yellow 200 Color Print canister
Status: Done

## Why
The yellow canister ("200 Color Print") currently uses Core Image's `photoEffectChrome`. The user wants it to look like a point-and-shoot digicam with flash at night, using the pipeline from the camera POC (given by the user in this change's request).

## Touches
tech.md (Camera line, FilmFilterPipeline notes), flows.md (none), ui.md (none)

## Changes
- MODIFIED: the "200 Color Print" filter (`RollFilter.colorPrint200`, yellow canister) gets the Digicam look. Same filter name, canister and id; not a new filter (user decision)
- UNCHANGED: Cinematic 400 Pro 35 B&W keeps `photoEffectNoir` (user decision)
- Digicam look (from the POC spec):
  - darker than the normal camera, warm (blue pressed most in the shadows), whites cream (never pure white), blacks slightly lifted, saturation a bit up, slightly soft with a thin edge sharpen, vignette, no grain
  - chain: 33³ color cube (exposure −0.6 EV in linear, S-curve 0.18 around 0.4, blue ×0.5 in shadows → ×0.85 in highlights via smoothstep on luma 0.1–0.8, saturation 1.2 Rec.709, output mapped to 0.03–0.9) → Gaussian blur 0.6 (clamped, cropped back) → sharpen luminance 0.4 → vignette 0.5 / 1.5
  - filter objects created once; only the input changes per frame; Metal `CIContext` (existing `RenderContext`)
- Same look on the live preview, the still photo and the Live Photo movie (as today, one pipeline for all)
- Still photo: downscaled to 2048 px long side **before** the look (Lanczos), so the blur / sharpen look like the preview (user decision). Today (change 014) the photo is downscaled after filtering; for the Digicam photo the 2048 px step moves before it. The B&W photo keeps today's behavior

## Tasks
- [x] `DigicamGrade` (color cube data, pure math) and the Digicam chain inside `FilmFilterPipeline` (`FilmLook.chrome` → Digicam), POC values
- [x] Photo path: Lanczos downscale to 2048 px before the Digicam look; encoder does not scale it again
- [x] Preview and Live Photo movie use the same chain (no downscale; their frames are already small)
- [x] Tests (Swift Testing): cube size (33³ × 4 floats); grade math (black → ≥0.03, white → ≤0.9 and blue < red, saturation / warmth direction); pipeline keeps the image extent; photo path output long side 2048; B&W unchanged
- [x] Build and run all tests on Simulator
- [x] Manual check on iPhone: yellow canister roll → preview, photo and Live Photo look like the Digicam spec and match each other; B&W unchanged — user confirmed on iPhone ("sudah saya cek semua")

## Out of scope
- New filters, canister / name changes
- Sample photos on the filter page (change 017)
- Grain / noise (the spec says none)

## Open
- Name in the UI stays "200 Color Print" although the look is Digicam; renaming is up to design

## Implementation findings
- `Core/Services/DigicamGrade.swift`: POC grade math and the 33³ cube, unchanged values
- `FilmFilterPipeline`: `FilmLook.chrome` renamed `.digicam`; Digicam chain (cube → blur 0.6 clamped / cropped → sharpen 0.4 → vignette 0.5 / 1.5) with filter objects created once per pipeline instance (one instance per queue, as before). `apply(_:to:forFinalPhoto:)`: only the still photo passes `true` (`CameraEngine` photo queue); preview and Live Photo movie frames are not scaled
- Downscale: Lanczos to 2048 px long side before the look. Lanczos with a `Float` scale can make one extra pixel (4032 → 2049 wide), so the output is cropped to the exact target size (input × scale, rounded down) instead of the POC's rounding of the output extent. `FilmPhotoEncoder`'s 2048 px step (014) then does nothing for Digicam photos; B&W photos are still scaled there, as before
- Tests: `ScrapItTests/Camera/DigicamFilterTests.swift` (cube size, lifted blacks / cream whites, darker and warmer, warmth strongest in shadows, preview keeps size, photo 2048 px, B&W not scaled by the pipeline); `CameraBehaviorTests` updated for `.digicam`. Full suite: 177 tests in 18 suites pass, 1 known issue (toggle contrast, 003)

