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
Figma node 613:1577
- Illustrated hanging lamp and two shelves with objects (camera, plant, sticker toolbox, books "memories", cat figurine, film canisters)
- Bottom tab bar: Home | Profile
- The camera object opens "Camera Roll" (the other objects are blurred behind it in that screen). Behavior of the other objects: [Open]
- Whether scrapbooks appear as books on the shelf: [Open]

## Screen: Camera Roll (Create / Join) [Locked]
Figma node 670:5276
- Back button, title "Camera Roll", camera illustration over blurred Home
- Buttons: "Create Roll", "Join a Roll"

## Screen: Create Roll, step 1 [Locked]
Figma node 675:5671
- Text field "Give this roll a name"
- Film strip selector "Select the number of shots": 24, 36 (selected by default), 48, 72
- Button "Next"

## Screen: Create Roll, step 2 choose filter [Draft]
Figma node 675:5759 (design still in progress)
- "Choose a filter": film canister picker ("Cinematic 400 Pro 35 Black & White", "200 Color Print") combined with a roll selection
- Intended: the film roll animates like a carousel and shows sample photos reflecting the currently selected filter (not final in the Figma frame)
- Button "Next"
- How a filter is applied (photos, Live Photos, timing) and whether more filters exist: [Open]

## Screen: Create Roll, step 3 share room (lobby) [Locked]
Figma node 675:5798
- QR code, 6-character "Roll code" (e.g. N4B1L), "Share link"
- Joined count ("5 Joined")
- Button "Start Roll" (host)

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
- ShelfCamera (666:4877): tappable camera on the Home shelf
- HangingLamp (663:4866), ShelfPlank (613:4330), ShelfPlant (613:4335), ShelfStickerBox (644:3450), ShelfBooks (652:3456), ShelfCat (666:4869), ShelfCanisters (644:3453): Home scene
- FilterCanisterBW (725:6301), FilterCanisterColor (725:6480): Choose filter

Note: designs are still in progress, so treat Figma-derived details as [Draft] until marked Locked.
