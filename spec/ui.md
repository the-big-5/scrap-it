# UI
Figma file: https://www.figma.com/design/ujlkuWobqxyvtQwh5plhGF/The-Big-Five (fileKey ujlkuWobqxyvtQwh5plhGF)
Frames are 402x874 (iPhone) unless noted. Style: warm cream background, hand-drawn film-camera illustrations, black pill buttons with a drop shadow, "film" theme. Terms: session = "Roll", photo = "shot".

## Screen: Welcome / Sign in [Locked]
Figma node 676:3703
- Logo placeholder at top, camera illustration
- Headline "Shoot together. Keep it forever."
- Subtext: "Sign in to start a shared roll with friends and keep every scrapbook on your shelf."
- Button "Sign in With Apple", terms/privacy text
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
## Screen: Scrapbook (basic grid after session) [Open] (design in progress)

## Assets
All illustrations are real Figma artwork in Assets.xcassets (@1x/@2x/@3x PNG, transparent):
- HeroCamera (678:4897): Welcome and Camera Roll camera
- ShelfCamera (666:4877): tappable camera on the Home shelf
- HangingLamp (663:4866), ShelfPlank (613:4330), ShelfPlant (613:4335), ShelfStickerBox (644:3450), ShelfBooks (652:3456), ShelfCat (666:4869), ShelfCanisters (644:3453): Home scene
- FilterCanisterBW (725:6301), FilterCanisterColor (725:6480): Choose filter

Note: designs are still in progress, so treat Figma-derived details as [Draft] until marked Locked.
