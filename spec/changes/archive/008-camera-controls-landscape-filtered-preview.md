# 008: Camera controls, landscape camera, filtered live preview, filtered Live Photo
Status: Done

## Why
Bring the camera behavior from the user's POC (`TBF/POC/Camera`, FilterCam, and its specs "Spec Tombol Fisik Kamera", "Spec Zoom Kamera", "Spec Aplikasi Kamera Filter iOS") into the Capture session screen:
- Physical buttons and Camera Control behave exactly like the POC
- The camera screen is landscape and photos are landscape
- The live preview shows the roll's filter in real time (photo = preview)
- Zoom follows the phone's real range with 0.1 precision, not hard-stopped at 0.5× / 2.0×
- Live Photos are captured and filtered too; a debug-only viewer lets the team check them

Change 007 (by a teammate) added the knurled zoom wheel and a Camera Control zoom slider + lens picker. This change keeps the wheel's look but replaces its 0.5 / 1 / 2 stops and the Camera Control setup with the POC behavior.

## Touches
ui.md (Capture session), tech.md (Camera, orientation, `.xcodeproj` exception), flows.md (F3: shots counter shows shots taken)

## Changes
- MODIFIED Capture session status: the parts below become [Locked] (the screen was [Draft]). Layout stays the current one (camera body, top deck, viewfinder, zoom wheel, shutter), shown in landscape
- MODIFIED orientation:
  - `.xcodeproj`: iPhone supported orientations add Landscape Left and Landscape Right. One-time exception to tech.md "Never touch .xcodeproj", approved by the user for this change
  - Capture session is landscape (left and right, following how the phone is held); every other screen stays portrait. Per-screen lock like the POC (`OrientationLock` + `UIApplicationDelegate.supportedInterfaceOrientationsFor` + `requestGeometryUpdate`)
  - Preview and photo rotation from `AVCaptureDevice.RotationCoordinator` per camera, re-created on camera flip and re-applied after session configuration; photos are landscape 4:3; preview = photo
- MODIFIED physical buttons (POC "Spec Tombol Fisik Kamera"), only on the Capture session screen:
  - Volume up: cycle flash (Off → On → Auto)
  - Volume down: flip camera on phones without Camera Control; take a photo on phones with Camera Control
  - Camera Control click: take a photo
  - Camera Control light press + slide: one "Zoom" control (`AVCaptureSlider`), same as the screen wheel: device minimum to 4×, steps of 0.1, lens values marked as prominent values, synced both ways with the wheel. No Front option and no lens picker (changed by user after approval, after device testing showed the lens picker only jumps between lenses). Flip stays on the FLIP button and volume down without Camera Control. With the front camera on, the slider is disabled (no zoom on the front camera)
  - REMOVED: Camera Control zoom slider (`AVCaptureSystemZoomSlider`) from 007; free zoom is on the screen wheel
  - ADDED Camera Adjustments pop-up (POC rules): on phones with Camera Control, ~1 s after the camera opens, at most once per app launch, until the app has seen the control open (`sessionControlsWillEnterFullscreenAppearance`) or the user answers. Buttons "Already On" / "Later" / "Don't Remind Me". State in `UserDefaults`. Text [Draft]: title "Turn On Camera Adjustments", message "To zoom and switch cameras with a light press on Camera Control, turn on Camera Adjustments in Settings › Camera › Camera Control."
  - Outside the Capture session the buttons work normally
- MODIFIED zoom wheel (`KnurledZoomWheelView`, keeps the 007 look and haptics):
  - Range: device minimum (0.5× with ultra wide, else 1×) to **4×** (or the device maximum if lower). Changed by user after approval (was: device maximum, up to 100×+; then 5×, which looked the same as 4× on device). Front camera: fixed at 1× on every phone, no wide / zoom (user decision)
  - Values snap to 0.1 (1.0, 1.1, 1.2, …), shown on the label
  - Direction (user request at approval): dragging the wheel to the **left** zooms in, like sliding on Camera Control (007 zoomed in to the right). Ribs roll the same way as the finger
  - Feels like Apple's Camera Control zoom slide: slow drag moves 0.1 at a time; faster drag covers more steps (velocity-based); the scale is logarithmic so 1×–2× gets as much travel as 2×–4×; light detent and snap haptic at lens values (e.g. 0.5×, 1×, 2×, 4×); hard endstop thud at min and max (no bounce)
  - One haptic tick per 0.1 step at slow speed, throttled when fast
  - Front camera: no zoom (1.0), wheel disabled
- MODIFIED live preview: shows the roll's filter in real time. Uses the app's existing filters (`RollFilter`: Cinematic 400 B&W = `CIPhotoEffectNoir`, 200 Color Print = `CIPhotoEffectChrome`) through one shared filter pipeline used by preview, photo and Live Photo video, so photo = preview. No filter switching on the camera screen (the filter is chosen when creating the roll). Preview pipeline follows the POC (`PreviewRenderer` / `FilterPipeline`)
- ADDED Live Photo (POC "Live Photo"): `AVCapturePhotoOutput` Live Photo (±1.5 s, no audio, no microphone permission) when the LIVE toggle is on and the camera supports it; the movie is filtered frame by frame with the same pipeline (POC `LivePhotoMovieWriter`), pairing metadata rewritten (content identifier, still-image-time); stored in `ScrapPhoto.livePhotoMovieData`. If the movie fails, the still photo is kept as a normal photo
- FIXED (found on device): the screen wheel and zoom label follow every zoom change, including Camera Control slides. The engine observes the camera's real `videoZoomFactor` and reports it, instead of relying only on control callbacks
- MODIFIED F3 shots counter (user request after approval): shows shots **taken** / total, from `00/36` up to `36/36` (was remaining shots, counting down from `36/36`). F3 text "everyone sees only the remaining shots" becomes "the number of shots taken out of the roll size" at merge
- ADDED debug Live Photo viewer (DEBUG builds only, never in TestFlight / App Store): a "Debug: last shot" button on the Capture session opens the last shot taken on this device; long press plays the Live Photo (`PHLivePhotoView`, from local files, no Photos permission). Exception to F3 "nobody sees photos during the roll", debug only

## Tasks
- [x] `.xcodeproj`: add Landscape Left / Right to iPhone supported orientations (nothing else in the project file)
- [x] `App/`: `OrientationLock` + app delegate adaptor; Capture session requests landscape on appear and portrait on disappear
- [x] `CameraController`: `RotationCoordinator`-based rotation for preview, photo and Live Photo; landscape 4:3 output
- [x] Shared filter pipeline in `Core/Services/` from `RollFilter` (Noir / Chrome), used by preview, photo and Live Photo video; replace the current photo-only `applyFilmFilter` path
- [x] Filtered live preview (video data output + renderer, POC approach) replacing the plain preview layer in the viewfinder
- [x] `ZoomCapabilities`: max = 4× (or the device maximum if lower); 0.1 quantization; lens values up to 4× for detents and the Cameras picker
- [x] `KnurledZoomWheelView`: continuous 0.1-step zoom over the device range, logarithmic scale, velocity-based stepping, lens detents, haptics as above; remove the fixed `ZoomStop` 0.5 / 1 / 2 stops (keep the visuals)
- [x] Camera Control: remove `AVCaptureSystemZoomSlider` and the lens picker; custom `AVCaptureSlider` "Zoom" (device min to 4×, step 0.1, lens values prominent), synced both ways with the wheel; disabled on the front camera
- [x] `CaptureEventView`: volume up = flash; volume down = flip (no Camera Control) / shutter (with Camera Control); Camera Control click = shutter
- [x] Camera Adjustments pop-up with the POC rules and `UserDefaults` state
- [x] Live Photo capture + filtered movie writer + pairing metadata; store movie in `ScrapPhoto.livePhotoMovieData`; fallback to still photo on failure
- [x] DEBUG-only "Debug: last shot" viewer with Live Photo playback
- [x] Wheel follows Camera Control: engine observes `videoZoomFactor` (back camera) and reports display zoom on 0.1 steps; controller updates `zoomFactor` from it
- [x] Shots counter: taken / total (`slotsUsed` / `rollSize`), starts at `00`
- [x] Tests (Swift Testing):
  - `ZoomCapabilities`: max 4× (lower device max respected), min with/without ultra wide, 0.1 quantization, lens list
  - Wheel mapping: logarithmic scale, slow drag = 0.1 steps, fast drag covers more steps, clamping at min/max
  - Button mapping: volume down = flip without Camera Control, shutter with Camera Control
  - Camera Adjustments pop-up state: shows at most once per launch, "Already On" / "Don't Remind Me" / detected control stop it, "Later" shows again next launch
  - Filter pipeline: B&W output is grayscale; same pipeline result for preview and photo input
  - Live Photo metadata: content identifier written to photo and movie match
  - Orientation mask per screen
  - Shots counter text: 00/36 at start, counts up with `slotsUsed`, 36/36 when full
- [x] Build and run all tests on Simulator
- [x] Manual check on a real iPhone with Camera Control (done by the user on iPhone 17 and iPhone Air, all passed): landscape left/right, preview = photo (filter and rotation), front camera upright, all buttons, Camera Control "Zoom" slider (0.1 steps to 4×, no Front), pop-up, wheel from 0.5× (iPhone 17) / 1× (iPhone Air) to 4× with 0.1 steps, Live Photo plays filtered in the debug viewer

## Out of scope
- Action Button / App Shortcut / Control widget
- Pinch to zoom
- Camera Control zoom slider, exposure slider, filter control
- Filter switching on the camera screen; new filters
- Uploading Live Photo movies to CloudKit (`CloudKitSessionService` stays photo-only) [Open]
- Showing Live Photos in the Scrapbook screen (only the debug viewer)
- Background Modes › Remote notifications (later, separate)
- Other `.xcodeproj` settings, signing, entitlements
- Layout redesign of the Capture session (current layout kept)

## Open
- Live Photo movies in CloudKit and in the Scrapbook screen
- Final Camera Adjustments pop-up text (English, [Draft])
- Exact wheel feel (speed curve, detent strength) tuned on device; values recorded at implementation

## Notes
- Change 007 behavior that changes here: 0.5× / 2.0× hard endstops, `ZoomStop` stops, Camera Control zoom slider. Tell the teammate who built 007
- Apple's Camera Control zoom slider is not a public spec; "feels like" means the behavior above (log scale, velocity, detents), checked on device
- Max zoom is 4× (user decision: 100×+ was too much, and above 4× looked unchanged on device)

## Implementation findings
- Camera engine ported from the POC as `Core/Services/CameraEngine.swift` (session queue, filtered preview, photo + Live Photo, rotation, Camera Control picker); `CameraController` is its main-actor face for the screen. Filter: `FilmFilterPipeline` (`RollFilter.look`: Noir / Chrome), used by preview, photo and Live Photo movie
- Zoom wheel logic lives in `Core/Models/ZoomWheelModel.swift` (testable): 110 pt of slow drag doubles/halves the zoom; speed gain starts above 150 pt/s (+1× per 250 pt/s, max 8×); detent holds 10 pt at each lens value on slow drags; fast drags pass lens values with a snap haptic only. Values are first guesses, to tune on device (Open)
- Wheel tap: left half jumps to the next lens value in (zoom in), right half to the next lens value out (matches the drag direction). 007 tapped right to zoom in
- Flash order is now Off → On → Auto (POC); default stays Auto as before
- The still photo is saved and claimed first; the filtered Live Photo movie is attached to `ScrapPhoto.livePhotoMovieData` when ready (about a second later). Simulator / no camera: the placeholder frame from before is kept
- `ZoomCapabilities`: max = min(4×, device maximum); lens values above 4× are not offered
- `.xcodeproj`: only `INFOPLIST_KEY_UISupportedInterfaceOrientations` changed (Portrait + Landscape Left + Landscape Right)
- Live Photo content identifier: ImageIO stores the MakerApple "17" field at UUID length, so it must be a UUID string (the app always uses one)
- Deleted at merge (user request; now unused): `Core/Models/ZoomStop.swift`, `Features/Roll/Components/CameraPreviewLayerView.swift`, and the `ZoomStop` / 0–2 index tests in `ZoomControlTests` (7 tests). Full suite after deletion: 75 tests pass, 1 known issue
- Tests: 82 tests in 8 suites pass (after the 4× / no-Front / Zoom slider / wheel-sync / counter updates) on iOS 27.1 Simulator (`IPHONEOS_DEPLOYMENT_TARGET=26.6` override), 1 known issue (toggle contrast from 003). New: `ScrapItTests/Camera/CameraBehaviorTests.swift` (27), `ZoomControlTests` +3
- The Simulator has no camera: filtered preview, rotation, Camera Control, volume buttons and Live Photo capture can only be checked on a real iPhone
- Camera Control "Zoom" is a custom `AVCaptureSlider` (not `AVCaptureSystemZoomSlider`, whose range cannot be limited to 4×): range from `ZoomCapabilities`, `step` 0.1, `prominentValues` = lens values, value shown as "1.2×". Slider and wheel update each other. The Simulator has no Camera Control, so this needs a device check
- Wheel sync fix: the engine now observes the back camera's `videoZoomFactor` (KVO) and reports the display zoom (0.1 steps, deduplicated) for any source; the wheel follows unless the finger is on it. Needs a device check (Camera Control does not exist in the Simulator)
- Shots counter: `RollFlowViewModel.takenShotsText` (`slotsUsed`, two digits) replaces `remainingShotsText`; `CaptureSession.remainingSlots` is unchanged and still used by `CloudKitSessionService` (join check, last-slot race)
- Wheel sync, second fix (first fix was not enough on device): the ribs looked still because a 0.1 Camera Control step near 1× moves the wheel ~15 pt with ribs every 16 pt (aliasing), and the animation interpolated the wrapped rib offset. Ribs are now drawn by an `Animatable` view from the continuous wheel travel, so each step rolls smoothly. The "finger on wheel" state now uses `@GestureState`, so a cancelled drag cannot block updates
- Orientation at merge: user noted portrait-only for the other screens is temporary; supporting both portrait and landscape later is recorded as [Open] in tech.md
