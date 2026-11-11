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

## Screen: Onboarding Slides [Locked]
Figma nodes 1248:21648 (OB1), 1249:22041 (OB2), 1255:22152 (OB3); changes 053, 054, 074
- Presented on app launch when not signed in, and upon sign-out, before displaying the Welcome screen; completing slide 3 smoothly dissolves to Welcome (change 074).
- 3-slide custom coordinator view with interactive horizontal drag scrubbing and animated button transitions (change 054).
- Transition animation: playful card shuffle inspired by Spark onboarding. Central illustration cards tilt, scale, and shuffle between slides, while peripheral decorative elements perform 3D flips and coordinates translation. Text crossfades in sync with transition progress (change 054).
- Element assets: individual transparent layer assets in `Assets.xcassets/Onboarding/` (change 054).
- Background: Kraft light active (`#F7F2EB`).
- Slide 1 (OB1): disposable camera and film collage illustration, headline "A film camera experience. Shared with friends.", body "Start a shared roll, take turns capturing your moment, and make every shot count.", button "Continue".
- Slide 2 (OB2): scrapbook notebook, scissors, and photos collage illustration, headline "Turn your memories into scrapbook.", body "Reveal your photos when the roll is complete, then create and decorate a scrapbook together.", button "Continue".
- Slide 3 (OB3): bookshelf scrapbooks and stars collage illustration, headline "Make memories you can revisit.", body "Keep your completed scrapbooks on your bookshelf and revisit the moments you made together.", button "Let's Try It" (transitions to Welcome screen, change 074).
- 3-dot page indicator above button (8pt circles, 8pt spacing; active dot ink `#2A241F`, inactive dot camera gray `#D2D0CB`).
- Large Primary button (`DSColor.Paper.light` pill with 1.5pt ink border, 7pt black shadow).

## Screen: Home [Locked]
Figma node 853:1703 (Idle) & 1062:3371 (CameraClick)
- Overhead desk workbench flat-lay: wood desk, green cutting mat with measurement numbers and ticks, red toolbox, blue book, spiral "TUTORIAL" book, film canisters, ruler, crumpled paper, stationery.
- Built from separate assets (one per Figma layer, folder `Assets.xcassets/Workbench/`), placed at their Figma frames. Layout: one uniform scale (Figma frame width = screen width), desk centered vertically; no status bar / tab bar printed in the assets.
- Interactive disposable camera resting at -14.77° on the cutting mat (Figma position).
- Camera return transition (changes 086, 100): exiting the capture session presents `CameraReturnTransitionOverlay` in portrait shell overlay; closes the mechanical iris diaphragm over the viewfinder, smoothly resizes from full-bleed to a floating camera card, performs a 3D horizontal Y-axis flip (preserving exit orientation: 0° portrait, ±90° landscape) to reveal the front disposable camera element, pops navigation silently underneath, fades out the dark background to reveal the workbench, and spring-animates the camera down to its idle spot on the cutting mat (-14.77°), restoring the floating tab bar.
- Camera tap interaction: camera rotates to 0.77° and centers with spring animation; the whole desk blurs as one page (flattened, then blurred) and dims; "Create Roll" and "Join a Roll" text buttons spring up from bottom with solid 7pt offset drop shadows. Tapping the blurred background or the round "<" close button at top left (Figma "Toolbar - Top") dismisses. Tab bar hidden while active.
- Tutorial book: the book image is the button (open stub for tutorial flow).
- Floating 2-tab navigation bar: Home (plus.circle.fill), Profile (books.vertical.fill). Tap a tab, or drag along the bar: the selection pill follows the finger and snaps to the nearest tab on release, with a selection haptic.

## Screen: Camera Roll (Create / Join) [Locked]
Integrated directly into the Workbench active popup state (Figma node 1062:3371).

## Screen: Create Roll Setup [Locked]
Figma node 984:3556
- Warm gradient header with stationery decorations (CreateRollHeaderDecoration).
- "Name your roll" input field.
- "Choose your shots" film strip selector: 24, 36 (default), 48, 72 with friendship guidance ("4-6 friends").
- Pill button "Next".

## Screen: Create Roll Filter [Locked]
Figma node 1187:8489 (replaces 675:5759, change 017)
- Header decoration and "Choose your filter".
- Film canister picker ("Cinematic 400 Pro 35 Black & White" vs "200 Color Print") with shot badge.
- Each canister's film strip: 4 sample photos (96 × 84 pt frames, horizontal scroll), filtered with that canister's real camera look. Only the selected canister's strip shows its photos; the other strip stays dark
- Pill button "Next".

## Screen: Create Roll Lobby [Locked]
Figma nodes 1282:21858 (host, change 019), 1187:9657 / 1187:9798 (participant + menu, change 019), 1011:6043 (Remove)
- Header decoration (ShareRoomHeaderDecoration), roll title (40 Bold), stats row: "N joined" (person.2, bold) and "N shots" (camera)
- Toolbar: X (close to the Workbench) on the left, "⋯" menu on the right (same round button; the label keeps its 3 pt offset shadow inside its frame so it does not flicker when the menu closes)
  - Host: Edit Room (`square.and.pencil`, shown, no action yet [Open]), Share Room (`square.and.arrow.up`), Delete Room (`trash`, red) → alert "Delete this room?" / "Everyone in the room will be removed." with Cancel and Delete Room [Draft text]
  - Participant: two rows only, Share Room on top, then Leave Room (`rectangle.portrait.and.arrow.right`, the HIG leave symbol instead of Figma's trash; red)
- Avatar grid, 3 per row: 100pt circles showing the participant's shared profile photo thumbnail when set, or initials (surface/ink or burgundy/paper, alternating by user [Draft]), name, "(Host)" / "(You)" (change 044).
- Host: "+" tile after the avatars (100 pt circle `Paper.normalHover`, SF Symbol `plus` 44 pt light in `Paper.darker`, Figma 1300:26199). Figma's "+" is a 75 pt text character (visible ≈ 38–40 pt); the 44 pt symbol gives the same visible size, centered and the same on every iPhone (user decision)
- Host: long-press another avatar → "Remove"; only the "Start Roll" pill at the bottom (the "Delete roll" text button moved into the menu)
- Participant: "Waiting for the host to start..." (20pt, Paper dark active) instead of the buttons
- Message on the Workbench after removal / deletion [Draft]: "The host removed you from the roll" / "This roll was deleted"

## Screen: Invite Friends Sheet [Locked]
Figma nodes 1300:26163 (options), 1300:26710 (room code); change 019. Host "+" tile and the camera screen's info button open it on the options page
- Medium-detent sheet, title "Invite Friends"
- Options page: X (close), `InviteHandshake` illustration (two phones on an orange burst), pills "Invite via AirDrop" and "Invite via Room Code"
- Invite via AirDrop: system share sheet with every built-in destination but AirDrop and the known messaging / social apps hidden (no public API opens AirDrop directly; unknown third-party extensions can't be hidden)
- Room code page: ← back to options, "Share this code with your friends to join the roll.", `InviteStars` illustration, the code in large spaced letters; long-press copies it ("Copied" + haptic) [Draft]
- No invite link yet / link failed: alert "Couldn't create the invite link. Check iCloud and your connection, then try again."

## Share Room (system share sheet) [Locked]
Figma 768:1623, from the lobby's "⋯" → Share Room (host and participant): AirDrop sends the iCloud link only; messaging apps get text only [Draft]: "Join my roll “<name>” on ScrapIt! 📸 / Roll code: <code> / <link>". Mail and other non-messaging destinations hidden. App name from one constant (`AppBrand.name`)

## Screen: Join a Roll [Locked]
Figma node 1187:9697 (change 019)
- Back button, title "Join Roll", `InviteHandshake` illustration, "Turn on AirDrop to accept the invite", divider, "Enter code" with 6 boxes (49×58) left-aligned with the label, "Join" pill. No header decoration
- One hidden text field holds the code; the boxes display it, the next box is outlined while typing; tapping a box opens the keyboard
- Joining overlay (change 024): full screen on `Paper.light`; `FilterCanisterColor` / `FilterCanisterBW` (switching every 2.4 s cycle) bobs and pulls `FilmStripAmber` out of its slit and back; status text 17 pt semibold `Brand.primary` [Draft text]: "Finding the roll…" (0 s), "Loading the film…" (3 s), "Almost there…" (8 s); "Cancel" (`Brand.tertiary`) at the bottom. Also for invite links. Reduce Motion: canister still, film strip fades
- Messages under the boxes, short only [Draft]: "Enter all 6 characters of the code", "No roll found for this code", "This roll has ended", "You're offline. Connect to the internet to join.", "Couldn't join. Make sure you're signed in to iCloud and try again." Cleared when the code changes

## Screen: Capture session [Locked]
Figma nodes 1458:26041 (reference landscape, front camera on left) and 1531:23441 (portrait orientation) (changes 041, 072). Camera behavior from the camera POC (FilterCam), change 008.
- Orientation: Interface orientation locked to portrait (matching Apple Camera app behavior, changes 008, 072). Camera body canvas remains in fixed reference landscape; individual symbols (Flash, Back, Flip, Shots-Left Dial, LIVE badge, Zoom text) rotate via accelerometer motion tracking while the camera body stays completely stationary without system window rotation transitions. Captured photos saved upright in portrait (90°) and landscape (0° / 180°). Exiting the Capture session initiates the multi-step return transition, resetting orientation to portrait without visible page rotation or navigation artifacts (changes 056, 072, 086).
- Camera-body UI (change 072):
  - Left deck: Upper recessed well (60×120) with Flash toggle (cycles Off/On/Auto with rotating symbol; default Off per node 1476:26501); lower recessed well (60×60) with Back navigation button (`arrow.left`), bottom aligned flush with the bottom of the viewfinder margin (y=370).
  - Viewfinder screen: 444.406×337 bezel with 424×318 live preview (4:3 ratio); mechanical iris diaphragm (8 equal circular blades) constricting on camera switch; participant count badge and debug last shot button removed; interactive `LIVE` badge button at top-left toggles Live Photo on/off (with diagonal slash when inactive).
  - Top plate: Knurled zoom wheel centered at x=594 with "ZOOM" factor text performing a 3D vertical flip (`rotation3DEffect`) when orientation shifts between landscape sides; hatch covers removed; wheel smoothly animates to 1.0x on switch to front camera and restores previous zoom on switch to back camera.
  - Top-right deck: Dedicated host-only "End Roll" recessed button (36×48, vertical portrait-baseline text, vertically centered with the zoom wheel at y=63); circular Info button removed. Tapping opens the "End this roll?" confirmation dialog (change 099).
  - Right deck: Circular shutter well (154×154) with silver spherical shutter dome (inner 130×130 dome depresses on tap while outer green ring stays fixed), Flip camera button in recessed well (72×72), and circular analog shots-left dial (83×83, outer frame with 55.865 inner drum, mechanical odometer digit tumblers, rotating face; displays a continuous rotating amber progress arc around the 83×83 rim during sync with a gentle sync pulse and single sharp mechanical decrement snap, change 058).
  - Legacy bottom controls shelf removed.
- Live preview shows the roll's filter in real time (Cinematic 400 B&W = Noir, 200 Color Print = Digicam, change 016); no filter switching on this screen
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
- No other users' photos shown; shows only own viewfinder and the remaining shots dial
- Camera capture popups (change 099; Figma 1517:25254 and 1512:26505):
  - Popups adapt dynamically to device orientation with matching rotation while camera body stays in reference landscape. Dimmed 40% black backdrop.
  - End roll confirmation (Figma 1517:25254): 337×294 pt, `#F6F1E7` background, 32 pt corners, angled washi tape at top center, centered film canister illustration (86×90), "End this roll?" (SF Pro Bold 24pt), body copy with dynamic shots left ("You still have 1 shot left..." / "You still have {N} shots left..."), "Cancel" button (108×52) and "Yes" button (169×52).
  - Roll complete popup (Figma 1512:26505): 337×337 pt, `#F6F1E7` background, 32 pt corners, washi tape, exposed film roll graphic (63×133), "Roll Complete!" (SF Pro Bold 24pt), natural or early finish body copy, "Reveal Photos" button (293×52).
  - Transitions: Appearance and dismissal fade via opacity; confirming "Yes" sequentially fades out confirmation over 200 ms, pauses 250 ms, and fades in roll complete over 200 ms. Navigating to reveal performs a root-level full-screen cross-fade through black, resetting orientation to portrait underneath without navigation or rotation artifacts.
- States (waiting for others, roll finished, offline queued, end session by host): [Open]

## Screen: Roll Reveal [Draft] (change 021; Figma 1323:41568, 1323:41482, 793:3352 grid only, 1444:23620)
Shown once after End Roll. No back button, no tab bar.
- Envelope: cutting mat (teal mat for every stage; Figma's olive mat on 1323:41482 not used [Open]), closed kraft envelope rotated −3°, paper label: roll name (Architects Daughter 28) and "1 photo" / "N photos" (Architects Daughter 16; the photos on this phone, no "/24"), updating as photos arrive (can lag a little behind friends' uploads [Open], see tech.md End Roll sync); while photos are missing (photos on this phone < the roll's shots used, first 10 s): "Printing your photos…" under the envelope (Architects Daughter 16, `Paper.light` with a soft shadow), the tear strip only gives a little and springs back, each new photo bounces the envelope and rolls the count up (numeric text); when all are in: "Your photos are ready!" for 2.5 s [Draft text] (change 024). Reduce Motion: no bounce, no rolling
- Tear: swipe across the top flap strip (about 110 pt or a fast swipe); the strip follows the finger and flies off, heavy haptic; the photos fly out to the mat one after another and the envelope fades
- Scattered: photos with a 1.5 pt white border, long side 150 pt, ±14° rotation, overlapping; drag moves a photo and brings it to the front; photos arriving later land on the mat
- "Tidy Up" (top right, 44 pt pill) → 2-column grid on Kraft light-active, 175 × 233 cells, 18 pt corners, capture time badge ("16:45"), scrolls; the button then reads "Scatter"
- "Start Scrapbook" (bottom, large pill) on both views → scrapbook editor
- Photo detail: 40% black dim, photo with a 5 pt white border (Live Photo plays on press), "Save" pill + share circle below it; tap outside closes. Save toast: "Saved to Photos" / "Couldn't save. Allow ScrapIt to add photos in Settings."

## Screen: Profile tab [Open] (design in progress, Figma 1109:4648)
- Header (Figma 1300:36485, change 044): `Kraft.lightActive` background, `120` pt circular avatar (user photo or gray placeholder), centered `20` pt Bold name + `pencil` button (opens Edit Profile), centered `13` pt bio (italic `"No bio yet"` when empty). Top-right share button (1300:36503) and wooden shelf (1300:36486 / 1109:4648) deferred [Open]
- Bookshelf spines (change 103, on the change 088 shelf): each spine is the scrapbook's spine from Edit Cover (spine art in the cover color with its pencil, stickers and text); no roll name, no palette; an undecorated spine shows only the color. Scrapbooks still being edited stay on the shelf for now (own page later)
- Covers below header (temporary, change 013, camera POC look): 2-column grid of covers (first page drawn small with stills and drawing, title, "N pages")
- Long-press a cover → "Delete" → confirmation "Delete this scrapbook?" / "Its photos on this phone are deleted too." [Draft]
- Empty: "Your scrapbooks appear here after a roll ends." [Draft]

## Screen: Edit Profile [Draft]
Figma node 1300:36781 (change 044)
- `Kraft.lightActive` background; top bar with `BackCircleButton` (`chevron.left`), `"Edit Profile"` title, and `CircleIconButton` (`checkmark`) to save
- `120` pt circular avatar with bottom-right `camera` badge opening `PhotosPicker` (and `"Remove Photo"` when set)
- Card 1 (`Paper.lightActive`, `1` pt `Brand.primary` border, radius `26`): editable `"Name"` (blank preserves existing name) and `"Bio"` rows
- `"Private Information"` header + Card 2: read-only `"Email"` row (`"Not provided"` fallback when `nil`)
- Bottom `"Log out"` pill (`OffsetPillButtonStyle`, `Paper.light`, `Brand.tertiary` text, `7` pt offset) → confirmation `"You'll need to sign in again to access your account."` with `"Log Out"` (destructive) and `"Cancel"`

## Screen: Scrapbook (book view + spread editor) [Open] (design in progress)
Book view and spread editor from Figma (change 025); tools from the camera POC (change 022).
- Book view (change 025, Figma 1444:23742 / 1518:30319): Workbench desk (`DeskWood`) and green cutting mat with grid, rulers 1–9 (drawn from the Figma layers); open book with the current spread (cover in the scrapbook's cover color with the cover grain and inner shadow, change 103); drag the book to turn a page in 3D around the spine (follows the finger, falls over past a third or with a flick; past the last spread the next pages are blank and are added); tap zooms the spread into the edit view (matched zoom); Back (top left) → confirmation card with washi tape and star, copy still the Figma placeholder "Back to … ?" / "Your scrapbook can be saved and continue to be edited later apalah" [Open, waiting for copywriting], Cancel / Yes; "Done" (primary, large) shown, no action yet; tooltip "More pages to fill!" / "You can swipe to another page and decorate it too." with X, once per user
- Edit view portrait (1274:33449 / 1537:25210 / 1536:24095): dark `Brand.primary` background; top bar X (back to the book), zoom (spread → left → right, icon shows the state), Who's here, Undo, Redo (disabled at the latest change); round white buttons with the ink offset shadow; "Live Photos paused in Low Power Mode" under the spread; the keyboard doesn't shrink the pages
- Edit view landscape (1563:30642 / 1563:30756 / 1563:31649 / 1563:30868): only on the spread (zoom hidden); buttons in a column on the notch side (Undo, Redo, Who's here at the top, X at the bottom); the tool tray stands on the other side, closed button upright at the bottom, swipe toward the screen edge closes it
- Who's here (1516:23450): sheet "Who's here" with X; "ON THIS PAGE" (this spread, me first as "Name (You)") and "ON OTHER PAGES" with "Page N"; avatar photo or colored circle with initial
- Cover screen (change 026, Figma 1515:29509 host / 1563:33405 participant / 1563:33594 finished): cutting mat with 20 / 100 pt grid and ticked edges (drawn from the Figma layers), the closed front cover; top right Editing Progress and "⋯" (Save as Video and Share shown, no action yet [Open]); bottom buttons: host Edit Cover + Save Scrapbook, participant Edit Cover + Done Editing, finished Back to Home; tap the book to read it
- Edit Cover (1444:23793 front, 1515:27196 spine): title "Edit Cover"; cover blue by default (`#303D6E`, from the Figma book 1444:23742) until someone picks a color, then the picked color (white included) (change 103), with the Figma material (texture grain kept over any color, spine hinge, inner shadow); tray open and fixed (centered, no scrolling, doesn't fold away) with this side's tools; swiping the second tray down puts the tool away (change 103); color picker button above the tray (system picker in a sheet); → to the spine, ✓ back to the cover screen; cover text in Architects Daughter, spine text upright and resizable up to the spine's width; stickers on the spine start at 60% of its width and can grow to its width (change 103); no undo / redo on the cover
- Editing Progress (1563:33166): sheet with X, "Done Editing" / "In Progress", profile photos (mine from my profile, friends' from presence or the room)
- Cards (star + washi, 1563:33117 / 1563:33675 / 1563:33475): "Ready to close the scrapbook?" (Keep Editing / Save Scrapbook), "Scrapbook Complete!" (View Bookshelf), "Nice Work!" (Got It)
- Pages: Figma paper (`#F6F1E7`, faint dots every 22 pt, inner shadow that marks the gutter); new items go to the page last touched (zoomed: that page); items stay on a zoomed page
- Tool tray (change 022, Figma 1306:48941 / 1306:48947): round red leather button (96 pt) at the bottom left → full-width main tray (106 pt, stitching inset 8 pt) with Scissors, Pencil, Stickers, Photos, Washi, Letters, Text; a tool opens a second tray overlapping 18 pt above; tapping the same tool or an empty spot closes it; swipe down (landscape: toward the screen edge) on the main tray folds it back and turns the tool off; light haptic per tool
- Items: photos (white print frame), stickers, letters, text, washi, drawing layers; tap selects and brings to front; drag / pinch / rotate (snaps to 0° within ±3°); a selected item (not drawing layers) has a bottom-right corner handle to resize / rotate with one finger; dragging any movable item reveals a floating animated trashcan (`ScrapbookTrashCanView`) above the bottom tray whose lid springs open on hover (item scales down/dims) and removes immediately on drop (stickers return to their sheet slot; uncut photos—or cut photos once all remaining pieces are removed—return to `PhotoTray`; leftover cut pieces discard only that piece); double tap: photo full screen, text edit; long-press menu: Bring to Front, Send to Back, Turn Off / On Motion (Live), Edit Text (text), Remove from Page; max 40 items per page, drawing layers included (change 062)
- Photos tray (1306:49859): this roll's photos as small polaroids keeping their own ratio (long side 52 pt, ±6°, newest left, Live badge); single-use across all pages of the scrapbook (shared live with collaborators) until removed; tap adds, drag up drops; empty: "Photos from this roll appear here." (empty roll) or "All photos from this roll are on the scrapbook." (all placed) (change 062)
- Stickers tray (1306:50103 / 1306:54411): Travel and Fun (27) sheets; the sheet opens over the pages on screen (83% width) over a dimmed spread, a sticker sticks to the page it's dropped on; peel–drag–stick, drop outside the sheet sticks, the sheet fades to 40% while dragging; single use per sheet synced live across collaborators (removed stickers return to their exact slot on the sheet unless reused on another page), "Take a New Sheet" synced via `.stickerSheetReset` (change 062)
- Scissors: first in the main tray; as the POC (drag to cut, long press to move—also activates the floating drag-to-trash target for leftover cut pieces—two fingers to pinch / rotate, scissors image, haptics); only photos are cut (change 062)
- Pencil (1306:50774, 1144:25595): Pen, Brush, Marker, Crayon, Fountain pen, Eraser (erases only where the finger passes, `.bitmap`), Pick color; tapping the active tool opens 5 sizes + opacity 10–100%; finger and Apple Pencil; no reed pen; on the spread both pages draw directly, each in its own layer; strokes are undone / redone with the top bar
- Washi (1306:49648 / 1306:56097): 4 rolls; pull on the page, straight tape with torn ends, haptic ticks, lift to tear; width 16% of the page, minimum 10%, opacity 0.88
- Letters (1306:49157): A–Z, 0–9, reusable; taps within 3 s line up to the right and wrap; drag up drops; height 12% of the page width
- Text: typing screen over the dimmed page, 7 colors, Done; system serif semibold; empty text isn't added
- Hints, once per scrapbook (first time the tool is on) [Draft text]: Scissors "Drag across a photo to cut. Long press to move.", Pencil "Draw with your finger." (iPhone) / "Draw with your finger or Apple Pencil." (iPad), Washi "Put your finger on the page and pull to stick washi tape"; on the two-page view the hint shows once, centered over both pages (change 103)
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
- Roll Reveal (folder `Reveal/`, change 021): RevealCuttingMat (@3x PNG, export of 1323:41569) and the envelope as SVG layers (EnvelopeBody, EnvelopeTextureA/B, EnvelopeFlap, EnvelopeFlapLine, EnvelopeLeftEdge, EnvelopeBottomFold); the body's SVG shadow is not drawn by iOS and is clipped in Figma anyway
- Loading (folder `Loading/`, change 024): FilmStripAmber (SVG, preserves vector, MID-Fi "Vintage Amber Film Strip" 1235:20885, Figma background rect removed); reuses FilterCanisterBW / FilterCanisterColor
- Scrapbook tool tray (change 022, copied from the camera POC): `Tray/` (tray-tool-*, tray-pencil-*, tray-washi-1…4, tray-pen-size-1…5), `Letters/` (letter-A…Z, letter-0…9, SVG), `Scrapbook/` sticker-fun-* (27) and sticker-sheet-fun
- Book view (folder `BookView/`, change 025): ScrapbookZoomSpread / ZoomLeft / ZoomRight and ScrapbookPeople (SVG glyphs from the Figma buttons, background removed), BookConfirmWashi (SVG), BookConfirmStar (@3x PNG cut from the Figma image, transparent); reuses DeskWood; BookCoverTexture (neutral grain made from the Figma cover image, change 026), BookConfirmStarWink (@3x PNG from the Figma image)

Note: designs are still in progress, so treat Figma-derived details as [Draft] until marked Locked.
