# UI
Figma file: https://www.figma.com/design/ujlkuWobqxyvtQwh5plhGF/The-Big-Five (fileKey ujlkuWobqxyvtQwh5plhGF)
Frames are 402x874 (iPhone) unless noted. Style: warm cream background, hand-drawn film-camera illustrations, black pill buttons with a drop shadow, "film" theme. Terms: session = "Roll", photo = "shot".

## Screen: Welcome / Sign in [Locked]
Figma node 676:3703
- Logo placeholder at top, camera illustration
- Headline "Shoot together. Keep it forever."
- Subtext: "Sign in to start a shared roll with friends and keep every scrapbook on your shelf."
- Button "Sign in With Apple", terms/privacy text
- Message above the button [Draft]: error "Couldn't sign in. Please try again."; offline "You're offline. Connect to the internet to sign in." (offline also disables the button)
- Logo is still a placeholder box [Open]

## Screen: Home [Locked]
Figma node 853:1703 (Idle) & 1062:3371 (CameraClick)
- Overhead desk workbench flat-lay: wood desk, green cutting mat with measurement numbers and ticks, red toolbox, blue book, spiral "TUTORIAL" book, film canisters, ruler, crumpled paper, stationery.
- Built from separate assets (one per Figma layer, folder `Assets.xcassets/Workbench/`), placed at their Figma frames. Layout: one uniform scale (Figma frame width = screen width), desk centered vertically; no status bar / tab bar printed in the assets.
- Interactive disposable camera resting at -14.77° on the cutting mat (Figma position).
- Camera tap interaction: camera rotates to 0.77° and centers with spring animation; the whole desk blurs as one page (flattened, then blurred) and dims; "Create Roll" and "Join a Roll" text buttons spring up from bottom with solid 7pt offset drop shadows. Tapping the blurred background or the round "<" close button at top left (Figma "Toolbar - Top") dismisses. Tab bar hidden while active.
- Tutorial book: the book image is the button (open stub for tutorial flow).
- Floating 3-tab navigation bar: Home (house.fill), Explore (magnifyingglass), Profile (person.fill). Tap a tab, or drag along the bar: the selection pill follows the finger and snaps to the nearest tab on release, with a selection haptic.

## Screen: Camera Roll (Create / Join) [Locked]
Integrated directly into the Workbench active popup state (Figma node 1062:3371).

## Screen: Create Roll Setup [Locked]
Figma node 984:3556
- Warm gradient header with stationery decorations (CreateRollHeaderDecoration).
- "Name your roll" input field.
- "Choose your shots" film strip selector: 24, 36 (default), 48, 72 with friendship guidance ("4-6 friends").
- Pill button "Next".

## Screen: Create Roll Filter [Locked]
Figma node 675:5759
- Header decoration and "Choose your filter".
- Film canister picker ("Cinematic 400 Pro 35 Black & White" vs "200 Color Print") with shot badge.
- Pill button "Next".

## Screen: Create Roll Lobby [Locked]
Figma nodes 1011:5883 (host), 768:1291 (participant), 1011:6043 (Remove), 1129:8947 (Leave roll)
- Header decoration (ShareRoomHeaderDecoration), roll title (40 Bold), stats row: "N joined" (person.2, bold) and "N shots" (camera)
- Toolbar: X (close to the Workbench) on the left. Host: "add person" button opens the Invite friend sheet. Participant: "⋯" menu with "Leave roll"
- Avatar grid, 3 per row: 100pt circles with initials (surface/ink or burgundy/paper, alternating by user [Draft]), name, "(Host)" / "(You)". Profile photos: [Open]
- Host: long-press another avatar → "Remove"; "Delete roll" (20pt, underlined, #AE1C1C) above the "Start Roll" pill
- Participant: "Waiting for the host to start..." (20pt, Paper dark active) instead of the buttons
- Message on the Workbench after removal / deletion [Draft]: "The host removed you from the roll" / "This roll was deleted"

## Screen: Invite Friend Sheet [Locked]
Figma node 1068:4233
- Medium-detent sheet: X (close), title "Invite friend", share button (top right; disabled until the link exists)
- "Roll code:" with 6 boxes (49×58, white, black border), "Copy link" (copies the iCloud link). No QR code
- While the link is missing: progress, or an error with "Try again" [Draft]
- Share (Figma 768:1623, system share sheet), host only: AirDrop sends the iCloud link only; messaging apps get text only [Draft]: "Join my roll “<name>” on ScrapIt! 📸 / Roll code: <code> / <link>". Mail and other non-messaging destinations hidden. App name from one constant (`AppBrand.name`)

## Screen: Join a Roll [Locked]
Figma node 725:6659
- Back button, title "Join Roll", "Enter code" with 6 single-character boxes (centered), "Join" pill
- Error messages under the boxes [Draft]: "No roll found for this code", "This roll has ended", "You're offline. Connect to the internet to join.", "Couldn't join. Make sure you're signed in to iCloud and try again."

## Screen: Capture session [Locked]
Figma node 708:4941 (landscape design). Camera behavior from the camera POC (FilterCam), change 008.
- Orientation: landscape only (supports both Landscape Left and Landscape Right dynamically even when system Portrait Orientation Lock is active; change 037); the other screens are portrait for now (see tech.md). Photos are landscape 4:3; preview = photo (same rotation and filter)
- Camera-body UI: flash toggle (Off / On / Auto, default Auto), LIVE (Live Photo) toggle, shots counter taken / total ("00/36" counting up to "36/36") with "SHOTS" label positioned above the counter box, knurled zoom wheel with "ZOOM" factor label positioned above the wheel (change 036), shutter button, viewfinder, red recording indicator, FLIP and GRID buttons
- Live preview shows the roll's filter in real time (Cinematic 400 B&W = Noir, 200 Color Print = Chrome); no filter switching on this screen
- Knurled zoom wheel (172×44, look from 007):
  - Back camera range: 0.5× (phones with ultra wide) or 1× up to 4× (or the device maximum if lower), in 0.1 steps
  - Drag **left** to zoom in; ribs roll with the finger; logarithmic scale; faster drags cover more steps
  - Light detent and snap haptic at lens values; hard endstop thud at min and max (no bounce); ratchet tick per 0.1 step
  - Tap left / right half: jump to the next lens value in / out
  - Follows zoom from Camera Control; front camera: fixed 1×, wheel disabled
- Camera Control (iOS 18+): click = take a photo; light press + slide = one "Zoom" slider (same range and 0.1 steps as the wheel, lens values marked), synced both ways with the wheel; no front camera option; disabled on the front camera
- Volume buttons (`AVCaptureEventInteraction`, only on this screen): volume up = cycle flash; volume down = take a photo on phones with Camera Control, flip camera on phones without it
- "Turn On Camera Adjustments" pop-up on phones with Camera Control: ~1 s after the camera opens, at most once per app launch, until the control has been seen opening or the user picks "Already On" / "Don't Remind Me" ("Later" asks again next launch). Text [Draft]: "To zoom and switch cameras with a light press on Camera Control, turn on Camera Adjustments in Settings › Camera › Camera Control."
- Live Photo (still + ~3 s movie, no audio), filtered like the photo; still photo kept if the movie fails
- DEBUG builds only: "DEBUG: LAST SHOT" button shows the last shot taken on this device, long press plays the Live Photo (exception to "no photos during the roll", debug only)
- No other users' photos shown; shows only own viewfinder and the shots counter
- Presence list during session is not in the design: [Open]
- States (waiting for others, roll finished, offline queued, end session by host): [Open]

## Screen: Profile tab [Open] (design in progress, Figma 1109:4648)
- Temporary (change 013, camera POC look): avatar placeholder, name, "Sign Out" (`DSButton` secondary), then a 2-column grid of covers (first page drawn small with stills and drawing, title, "N pages")
- Long-press a cover → "Delete" → confirmation "Delete this scrapbook?" / "Its photos on this phone are deleted too." [Draft]
- Empty: "Your scrapbooks appear here after a roll ends." [Draft]

## Screen: Scrapbook editor [Open] (design in progress)
Temporary look from the camera POC (change 013). Stickers, backgrounds and scissors may change with the design.
- Header: back button, title, Undo (cuts), "Done" while scissors / pencil are on
- 3:4 page with shadow, page indicator "n / N" with arrows, "Live Photos paused in Low Power Mode"
- Toolbar: Photos (+), Background, Stickers, Scissors, Pencil, Pages menu (Add Page, Move Left / Right, Delete Page with confirmation)
- Items: white print frame; tap selects and brings to front; drag / pinch / rotate (snaps to 0° within ±3°); long-press menu: Bring to Front, Send to Back, Turn Off / On Motion (Live), Remove (stickers with confirmation)
- Photo picker: only this roll's photos, Live marked, numbered selection, max 20 items per page
- Stickers: POC "Travel" sheet panel at the bottom, drag a sticker onto the page, each used once, "Take a New Sheet"
- Scissors: as the POC (drag to cut, long press to move, two fingers to pinch / rotate, scissors image, haptics)
- Pencil: PencilKit layer over the page, system tool picker with all iOS 18 tools except the reed pen, finger drawing allowed
- Toast "This page is full"

## Design system [Locked]
Figma page "Design System #2" (628:4011), Atoms and Molecules only. Code: `Core/DesignSystem/` (`DS` prefix). Existing `ScrapTheme`, `OffsetPillButtonStyle`, `BackCircleButton` stay until screens are migrated.

### Colors (`DSColor`, names follow Figma) — node 629:4298
- Brand: primary `#2A241F`, secondary `#EBCB6B`, tertiary `#6B2430`
- State: info `#2F80ED`, success `#27AE60`, warning `#E2B93B`, error `#E50935`
- Camera: leather `#9A5531`, camera `#D2D0CB`, cognac `#6E3A20`
- Scales Paper, Kraft, Green: light, lightHover, lightActive, normal, normalHover, normalActive, dark, darkHover, darkActive, darker (values in `DSColor.swift`)
- Component: field `#EBE2D3`, surface `#FFFDF8`, placeholder `#6E6458`, textSecondary `#5E5449`, disabledText `#8A7F73`, disabledBackground `#E9E1D3`, inputError `#A8382A`, fillTertiary `#767680` 12%, labelTertiary `#3C3C43` 30%, toggleOffLabel `#B3B3B3`, white `#FFFFFF`
- Dark mode: dark values equal light for now [Open]

### Typography (`DSTypography`, `.dsTypography(_:)`) — nodes 629:5503, 629:5466, 643:930
- Headings, SF Pro, line height 1.1×: h1 56, h2 48, h3 40, h4 32, h5 24 (Bold); h6 20 (Medium)
- Body, line height 1.4×, Bold and Regular: large 20, medium 18, normal 16, small 14
- Two body families: SF Pro and Architects Daughter (handwritten). Architects Daughter has only Regular; "Bold" uses it. Font is bundled and registered at runtime
- Fixed sizes, no Dynamic Type for now
- Which text uses SF Pro vs Architects Daughter: [Open], decided per screen

### Elevation (`DSElevation`)
- One level: solid primary shape offset y 5 (y 2 when pressed), from `OffsetPillButtonStyle`
- Full level set: [Open]

### Buttons — node 629:5343
- `DSButton` / `DSButtonStyle`: primary (white on ink), secondary (burgundy on fillTertiary), tertiary (leather Semibold, no background)
- Sizes: small 32, normal 44, large 52; optional full width; minimum tap target 44
- Disabled is a state of any variant (fillTertiary background, labelTertiary text)
- Pressed: 0.7 opacity (not in Figma) [Open]
- `DSIconButton` 44 circle (primary, secondary, tertiary, disabled); `DSBackButton` 28 / 34 / 50
- Icons: Figma SVGs in `Assets.xcassets/DesignSystem/` (plus, play, check, close, eye-slash, search)

### Inputs & controls — node 629:5426
- `DSTextField`: kinds plain, password (show/hide), search (magnifier + clear), caption (multi-line); states initial, active (focused or filled), error (with message)
- Password uses the same eye-slash icon for shown and hidden [Open]
- `DSRadio`, `DSCheckbox`, `DSToggle`

### Known issues and Figma inconsistencies [Open]
- Toggle off track contrast 1.70:1 (below WCAG 3:1)
- Error color: swatch caption `#EB5757` vs fill `#E50935`; input error uses `#A8382A`
- Typography page shows Bold; Button component uses Regular (Tertiary Semibold)

## Assets
All illustrations are real Figma artwork in Assets.xcassets (@1x/@2x/@3x PNG, transparent):
- HeroCamera (678:4897): Welcome and Camera Roll camera
- Workbench (folder `Workbench/`, Figma 853:1703): DeskWood (JPEG), DeskMatShadow, DeskShading, DeskCuttingMat, DeskMeasurements, DeskWoodGrain, DeskToolbox, DeskBookBottom, DeskBookTutorial, DeskRuler, DeskFilmRoll2..4, DeskPaperBall1..2, DeskStationery1..5. Exports are cut at the Figma frame edge; those parts are never on screen
- DeskDisposableCamera (catalog root, reusable): Workbench camera
- Flow headers: CreateRollHeaderDecoration, ShareRoomHeaderDecoration
- FilterCanisterBW (725:6301), FilterCanisterColor (725:6480): Choose filter

Note: designs are still in progress, so treat Figma-derived details as [Draft] until marked Locked.
