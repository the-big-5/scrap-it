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
- Overhead desk workbench flat-lay: green cutting mat with measurement ticks, red toolbox, books, film canisters, ruler, paper scraps, stationery.
- Interactive disposable camera resting at -14.77° on the cutting mat.
- Camera tap interaction: camera rotates to 0.77° and centers with spring animation, background blurs and dims, "Create Roll" and "Join a Roll" action buttons spring up from bottom with solid 7pt offset drop shadows. Tapping blurred background dismisses.
- Stacked tutorial books (open stub for tutorial flow).
- Floating 3-tab navigation bar: Home (house.fill), Explore (magnifyingglass), Profile (person.fill).

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
Figma nodes 1011:5883 & 768:1382
- Header decoration (ShareRoomHeaderDecoration), roll title, stats row showing joined count (person.2) and shot count (camera).
- Top-right toolbar button (qrcode / invite) opens the "Invite Friend" sheet.
- Participant avatar grid: host with "(Host)" badge, user with "(You)" badge, joined friends with photo or monogram initial badges.
- Pill button "Start Roll" (host-enabled; guests see disabled "Waiting for host...").

## Screen: Invite Friend Sheet [Locked]
Figma node 768:1483
- Medium-detent bottom sheet.
- QR code representation, "Roll code:" with 6 monospace character boxes, "Copy link" clipboard button.

## Screen: Join a Roll [Draft]
Figma node 725:6659 (placeholder, design still in progress)
- Back button, title "Join Roll"
- "Scan QR" camera viewfinder area (placeholder box)
- "or Enter code": 6 single-character boxes
- Button "Join Roll"

## Screen: Capture session [Draft]
Figma node 708:4941 (design frame is landscape; the app itself supports all orientations)
- Camera-body UI: flash toggle (AUTO), LIVE (Live Photo) toggle, shots counter "09/36", zoom 1.0x, shutter button, viewfinder with "LIVE" badge and zoom label, red recording indicator, FLIP and GRID buttons
- No other users' photos shown; shows only own viewfinder and shots remaining
- Presence list during session is not in the design: [Open]
- States (waiting for others, roll finished, offline queued, end session by host): [Open]

## Screen: Profile tab [Open] (design in progress)
- Temporary "Sign Out" button (`DSButton` secondary) until the design is ready
## Screen: Scrapbook (basic grid after session) [Open] (design in progress)

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
- Workbench flat-lay: WorkbenchBackgroundIdle, WorkbenchBackgroundActive, DeskDisposableCamera, DeskCuttingMat, DeskSurface, DeskMeasurements, DeskFolder, DeskBookTop, DeskBookBottom, DeskRuler, DeskFilmRoll2..4, DeskStationery1..5, DeskTape1..2
- Flow headers: CreateRollHeaderDecoration, ShareRoomHeaderDecoration
- FilterCanisterBW (725:6301), FilterCanisterColor (725:6480): Choose filter

Note: designs are still in progress, so treat Figma-derived details as [Draft] until marked Locked.
