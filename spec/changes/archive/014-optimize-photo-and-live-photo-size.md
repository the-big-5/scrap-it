# 014: Optimize Captured Photo and Live Photo Storage Size
Status: Done

## Why
Captured photos and Live Photo movies currently consume ~10 MB to ~14 MB per shot because images are saved at full sensor resolution (12MP–48MP) with an aggressive 90% JPEG quality, and Live Photo movies are encoded without bitrate or resolution constraints. This fills local storage unnecessarily and consumes excessive bandwidth and CloudKit storage when rolls are finalized. Proportional resizing to 2048px (preserving the exact 4:3 aspect ratio without cropping), tuning JPEG compression to 0.78, and adding an HEVC bitrate cap to Live Photo movies reduces shot size by ~85% (~1.4 MB total per shot) while preserving visual sharpness on all iPhone and iPad displays.

## Touches
tech.md (Camera, Media), flows.md (F3: Roll), ui.md (Capture session)

## Changes
### 1. Photo Still Proportional Downscale & Compression
- MODIFIED `FilmPhotoEncoder.jpegData`:
  - If the filtered image extent's longest dimension exceeds 2048 pixels, apply proportional bilinear/bicubic scaling so the max edge is 2048px (e.g. 2048 × 1536 for standard 4:3 landscape shots).
  - Exact aspect ratio (4:3) is strictly preserved; **zero cropping**.
  - Adjust `kCGImageDestinationLossyCompressionQuality` from `0.9` to `0.78`.
  - Live Photo pairing metadata (`kCGImagePropertyMakerAppleDictionary` with `contentIdentifierKey`) is preserved intact.

### 2. Live Photo Movie Resolution & Bitrate Constraint
- MODIFIED `LivePhotoMovieWriter`:
  - Constrain the output video dimensions proportionally so the longest edge does not exceed 1440px (1080p standard for Live Photos, e.g. 1440 × 1080).
  - Add `AVVideoCompressionPropertiesKey` with `AVVideoAverageBitRateKey` set to ~2.5 Mbps (`2_500_000` bps) and HEVC profile (`AVVideoProfileLevelHEVCMainAutoLevel`).
  - Preserve QuickTime still-image-time metadata track and content identifier pairing so iOS continues to recognize it as a valid Live Photo.

### 3. Pipeline Integrity
- Filter look (Color Print 200 / B&W 400), grain, and orientation remain identical across preview, still photo, and movie.

## Tasks
- [x] Add proportional scaling helper to `FilmPhotoEncoder` capping max edge at 2048px while maintaining aspect ratio
- [x] Update `FilmPhotoEncoder.jpegData` to render scaled image and set lossy compression quality to 0.78
- [x] Update `LivePhotoMovieWriter` output video settings with dimension capping (max edge 1440px) and average bitrate 2.5 Mbps
- [x] Add unit tests in `CameraBehaviorTests.swift` (or dedicated test suite):
  - Verify large CIImage (e.g. 4032 × 3024) encodes to max 2048 × 1536 without altering aspect ratio
  - Verify Live Photo content identifier metadata persists after downsampling and compression
  - Verify compressed still photo byte size is substantially reduced (<1 MB)
  - Verify filtered Live Photo movie retains still-image-time and content identifier
- [x] Run full test suite to ensure zero regressions across existing tests

## Out of scope
- Changing camera preview or viewfinder resolution
- Altering the film filter shaders or looks
- Modifying CloudKit upload lifecycle (handled in a separate task)
- Cropping or changing 4:3 aspect ratio
