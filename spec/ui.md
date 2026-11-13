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
Figma nodes 853:1703 (Portrait Idle), 1062:3371 (CameraClick), 1230:20656 (ToolboxClick), 1235:21168 (RollsClick), and 1563:34278 (iPad 13" Landscape Idle); changes 086, 100, 104, 105, 106.
- Overhead desk workbench flat-lay: wood desk, green cutting mat with measurement numbers and ticks, red toolbox, blue book, spiral "TUTORIAL" book, film canisters, ruler, crumpled paper, stationery.
- Adaptive layout (`WorkbenchLayout`, change 105): `.portrait` (`402 × 874`, `853:1703`) for iPhone and iPad Portrait; `.iPadLandscape` (`1210 × 834`, `1563:34278`) when `idiom == .pad && width > height` (full-bleed `DeskWoodLandscape`, vector `LandscapeCuttingMatView` numbered `1...27`, `DeskBookBottomLandscape`, reused `InteractiveToolboxView`, `DeskDisposableCamera`, `DeskBookTutorial`, and `InteractiveRollsView`). Both scale uniformly by width (`origin.y` centered vertically); no status bar / tab bar printed in the assets.
- Interactive disposable camera resting at -14.77° on the cutting mat (Figma position).
- Camera return transition (changes 086, 100, 110): exiting the capture session presents `CameraReturnTransitionOverlay` in portrait shell overlay; closes the mechanical iris diaphragm over the viewfinder, zooms out from the optical viewfinder window of `DeskDisposableCameraBack` (`3.5×` viewport cover) to a centered floating camera card, performs a 3D horizontal Y-axis flip (preserving exit orientation: 0° portrait, ±90° landscape) to reveal the front `DeskDisposableCamera` element, pops navigation silently underneath, fades out the dark background to reveal the workbench, and spring-animates the camera down to its idle spot on the cutting mat (-14.77°), restoring the floating tab bar.
- Camera tap interaction: camera rotates to 0.77° and centers with spring animation; the whole desk blurs as one page (flattened, then blurred) and dims; "Create Roll" and "Join a Roll" text buttons spring up from bottom with solid 7pt offset drop shadows. Tapping the blurred background or the round "<" close button at top left (Figma "Toolbar - Top") dismisses. Tab bar hidden while active.
- Toolbox tap interaction (Figma 1230:20656 / 1230:20860, change 104): persistent layered `InteractiveToolboxView` (`DeskToolboxBase` + 8 loose tool sprites) glides and scales to screen center across blurred/dimmed desk while hiding the tab bar, plays a rhythmic ~`0.90` s rattle with secondary tool inertia and haptics (`Reduce Motion` supported), and auto-pushes **"Resume Editing"** (`.deskCollection(.scrapbooks)`).
- Film canisters tap interaction (Figma 1235:21168, changes 106, 110): tapping any of the 3 resting film canisters (`DeskFilmRollYellow`, `DeskFilmRollGreen`, `DeskFilmRollRed` on both Portrait and iPad Landscape) hides the tab bar, blurs and dims the desk, glides and fans the 3 canisters at full vibrant opacity into the centered `1235:21168` cluster with spring bounce and haptics (`~0.85` s), and auto-pushes **"Resume Roll"** (`.deskCollection(.rolls)`).
- Tutorial book: the book image is the button (open stub for tutorial flow).
- Native TabView navigation bar (change 088): `Tab("Craft", systemImage: "camera.fill", value: AppTab.home)` and `Tab("Library", systemImage: "books.vertical.fill", value: AppTab.profile)`, styled with `DSColor.Kraft.darker` tint. Bar visibility during Workbench camera overlay controlled via `.toolbarVisibility(router.shouldShowTabBar ? .visible : .hidden, for: .tabBar)`.

## Screen: Camera Roll (Create / Join) [Locked]
Integrated directly into the Workbench active popup state (Figma node 1062:3371).

## Screen: Resume Editing [Draft]
Figma nodes 1537:25855 (populated) & 1537:25830 (empty); change 104.
- Uses `DeskCollectionView` (`DSColor.Kraft.lightActive` background, native navigation bar back button, centered `"Resume Editing"` title).
- Populated (`1537:25855`): 2-column grid of tactile `FolderPreviewCard` items for scrapbooks not saved yet (change 125; saved ones are on the Library shelf), newest first, cycling 3 folder themes (Burgundy, Kraft/Tan, Navy/Slate), formatted `dd/MM/yyyy` creation dates, and `0...4` real peeking photos seeded stably per `scrapbook.id`. Long-press offers local-only removal with confirmation dialog.
- Empty (`1537:25830`): `DeskEmptyStateView` with `ToolboxEmptyIllustration`, `"No scrapbook in progress...yet!"`, `"Every scrapbook starts with a roll. Gather your friends and capture moments together."`, and `"Create Roll"` primary pill (`DSButton`) → `CreateRollSetupView`.

## Screen: Resume Roll [Draft]
Figma nodes 1537:26016 (populated) & 1537:25997 (empty); change 106.
- Uses `DeskCollectionView` (`DSColor.Kraft.lightActive`, native navigation bar back button, centered `"Resume Roll"` title).
- Populated (`1537:26016`): vertical list of `RollStripCard` rows (newest `startTime` first), each pairing an upright filter canister (`FilterCanisterBW` or `FilterCanisterColor`) with a trailing-bleeding `#2A241F` film strip bordered by perforated black sprocket rails showing roll title, `person.2` `{N} joined`, `camera` `{slotsUsed}/{rollSize} shots`, and `dd/MM/yyyy` date. Long-press offers `Leave Roll` (safe host handover when others remain) and (when host) `Delete Roll` with confirmations.
- Empty (`1537:25997`): `DeskEmptyStateView` with `RollEmptyIllustration` (camera, 200/400 canisters, winding amber film leader, 3 yellow star characters), `"No roll in progress...yet!"`, `"Your next little moments are waiting to be captured. Start a roll and make memories with your friends."`, and `"Create Roll"` primary pill (`DSButton`) → `CreateRollSetupView`.

## Screen: Create Roll Setup [Locked]
Figma node 984:3556
- Warm gradient header with stationery decorations (CreateRollHeaderDecoration).
- "Name your roll" input field.
- "Choose your shots" film strip selector: 24, 36, 48, 72, nothing picked at first; guidance under it per pick: "suitable for 2-3 friends" (24), "4-6" (36), "7-8" (48), "8+" (72), nothing before a pick (change 081).
- Shot picker frames (Figma "Shot Picker" 1717:63264, change 081; also on Edit Roll): the picked frame is `Brand.primary` with a white 34 pt heavy number and four viewfinder corner brackets (`ShotBracket…`, 14 pt, 8 pt in from the corners); the others `Kraft.darker` with a 30 pt heavy number in `Paper.dark`; 2 pt black between frames, 80 pt high; light selection haptic; VoiceOver "<n> shots" with the selected trait
- "Next" (design-system primary button), disabled in the Figma disabled look until the name has text and a count is picked (change 081).

## Screen: Create Roll Filter [Locked]
Figma node 1571:48191 (change 081; replaces 1187:8489)
- ‹ and title "Create Roll" ("Edit Roll" when editing, 1600:49849), "Pick a filter", no header decoration.
- Film canister picker ("Cinematic 400 Pro 35 Black & White" vs "200 Color Print") with shot badge.
- Each canister's film strip: 4 sample photos (96 × 84 pt frames, horizontal scroll), filtered with that canister's real camera look. Both strips show their photos; the picked film's photos run by themselves like a carousel (still with Reduce Motion) and its canister grows. The strip takes the screen's width, the photos are cut at its edge (change 081)
- "Done" (design-system primary button): creates the roll, or saves the edits (change 081).

## Screen: Edit Roll [Locked]
Figma nodes 1599:49098 (menu), 1599:49590 (setup), 1600:49849 (filter); change 081
- Host only, before the roll starts (Edit Room isn't in the menu after): ‹, "Edit Roll" (34 bold), "Capture moments with limited shots, revealed when the roll is complete.", "Name your roll" field and "Pick how many photos to shot" strip with the roll's values, the same guidance and Next rule; Next → the filter step titled "Edit Roll" → Done saves name, shots and filter to the room

## Screen: Create Roll Lobby [Locked]
Figma nodes 1282:21858 (host, change 019), 1187:9657 / 1187:9798 (participant + menu, change 019), 1011:6043 (Remove)
- Header decoration (ShareRoomHeaderDecoration), roll title (40 Bold), stats row: "N joined" (person.2, bold) and "N shots" (camera)
- Toolbar: X (close to the Workbench) on the left, "⋯" menu on the right (same round button; the label keeps its 3 pt offset shadow inside its frame so it does not flicker when the menu closes)
  - Host: Edit Room (`square.and.pencil`, only before the roll starts → Edit Roll), Share Room (`square.and.arrow.up`), Delete Room (`trash`, red) → the Delete Roll card (Figma 1600:50620): star card with washi and the squinting star, "Delete Roll?" / "This roll will be gone for good and you won't be able to get it back.", "Keep Roll" (dark) and "Delete Roll" (light, red text) (change 081)
  - Participant: two rows only, Share Room on top, then Leave Room (`rectangle.portrait.and.arrow.right`, the HIG leave symbol instead of Figma's trash; red)
- Avatar grid, 3 per row: 100pt circles showing the participant's shared profile photo thumbnail when set, or initials (surface/ink or burgundy/paper, alternating by user [Draft]), name, "(Host)" / "(You)" (change 044).
- Host: "+" tile after the avatars (100 pt circle `Paper.normalHover`, SF Symbol `plus` 44 pt light in `Paper.darker`, Figma 1300:26199). Figma's "+" is a 75 pt text character (visible ≈ 38–40 pt); the 44 pt symbol gives the same visible size, centered and the same on every iPhone (user decision)
- Host: long-press another avatar → "Remove"; only the "Start Roll" pill at the bottom (the "Delete roll" text button moved into the menu). A started roll reopened from Resume Roll shows "Continue Roll" instead, for host and participants (Figma 1672:29659, change 081)
- Participant: "Waiting for the host to start..." (20pt, Paper dark active) instead of the buttons
- Message on the Workbench after removal [Draft]: "The host removed you from the roll". After deletion, the "Roll Deleted" card (Figma 1600:50745): happy star, "Roll Deleted" / "All set. Start a new roll whenever you're ready.", no buttons, gone after about 2.5 s or on a tap (change 081)

## Screen: Invite Friends Sheet [Locked]
Figma nodes 1300:26163 (options), 1300:26710 (room code); change 019. Host "+" tile and the camera screen's info button open it on the options page
- Medium-detent sheet, title "Invite Friends"
- Options page: X (close), the invite illustration (Figma 1599:49022: two phones with the two star characters, change 081), pills "Invite via AirDrop" and "Invite via Room Code"
- Invite via AirDrop: system share sheet with every built-in destination but AirDrop and the known messaging / social apps hidden (no public API opens AirDrop directly; unknown third-party extensions can't be hidden)
- Room code page: ← back to options, "Share this code with your friends to join the roll.", `InviteStars` illustration, the code in large spaced letters; long-press copies it ("Copied" + haptic) [Draft]
- No invite link yet / link failed: alert "Couldn't create the invite link. Check iCloud and your connection, then try again."

## Share Room (system share sheet) [Locked]
Figma 768:1623, from the lobby's "⋯" → Share Room (host and participant): AirDrop sends the iCloud link only; messaging apps get text only [Draft]: "Join my roll “<name>” on Rèlic! 📸 / Roll code: <code> / <link>". Mail and other non-messaging destinations hidden. App name from one constant (`AppBrand.name`, change 134)

## Screen: Join a Roll [Locked]
Figma node 1187:9697 (change 019)
- Back button, title "Join Roll", the invite illustration (change 081), "Turn on AirDrop to accept the invite", divider, "Enter code" with 6 boxes (49×58) left-aligned with the label, "Join Roll" button (design-system primary), disabled until all 6 characters are in (Figma 1663:46361, change 081). No header decoration
- One hidden text field holds the code; the boxes display it, the next box is outlined while typing; tapping a box opens the keyboard
- Joining overlay (change 024): full screen on `Paper.light`; `FilterCanisterColor` / `FilterCanisterBW` (switching every 2.4 s cycle) bobs and pulls `FilmStripAmber` out of its slit and back; status text 17 pt semibold `Brand.primary` [Draft text]: "Finding the roll…" (0 s), "Loading the film…" (3 s), "Almost there…" (8 s); "Cancel" (`Brand.tertiary`) at the bottom. Also for invite links. Reduce Motion: canister still, film strip fades
- Messages under the boxes, short only [Draft]: "No roll found for this code", "This roll has ended", "You're offline. Connect to the internet to join.", "Couldn't join. Make sure you're signed in to iCloud and try again." Cleared when the code changes. No "Enter all 6 characters" since the button waits for the full code (change 081)

## Screen: Capture session [Locked]
Figma nodes 1458:26041 (reference landscape, front camera on left) and 1531:23441 (portrait orientation) (changes 041, 072). Camera behavior from the camera POC (FilterCam), change 008.
- Orientation: Interface orientation locked to portrait (matching Apple Camera app behavior, changes 008, 072). Camera body canvas remains in fixed reference landscape; individual symbols (Flash, Back, Flip, Shots-Left Dial, LIVE badge, Zoom text) rotate via accelerometer motion tracking while the camera body stays completely stationary without system window rotation transitions. Captured photos saved upright in portrait (90°) and landscape (0° / 180°). Exiting the Capture session initiates the multi-step return transition, resetting orientation to portrait without visible page rotation or navigation artifacts (changes 056, 072, 086).
- Camera intro transition (change 110): starting a roll from `CreateRollLobbyView` (host or joining participant) presents `CameraIntroTransitionOverlay` above the navigation stack: fades `350` ms to a blank `#F4EFE6` paper screen, pushes `.captureSession` with animations disabled underneath, plays the 3D disposable camera loading sequence (`CameraIntroWebView` / `CameraIntroHTMLTemplate`) with the roll's selected canister (`FilterCanisterColor` or `FilterCanisterBW`) and synchronized mechanical haptics ("Press anywhere to skip" supported), and cross-fades `400` ms into the live `CaptureSessionView`.
- Camera-body UI (change 072):
  - Left deck: Upper recessed well (60×120) with Flash toggle (cycles Off/On/Auto with rotating symbol; default Off per node 1476:26501); lower recessed well (60×60) with Back navigation button (`arrow.left`), bottom aligned flush with the bottom of the viewfinder margin (y=370).
  - Viewfinder screen: 444.406×337 bezel with 424×318 live preview (4:3 ratio); mechanical iris diaphragm (8 equal circular blades) constricting on camera switch; participant count badge and debug last shot button removed; interactive `LIVE` badge button at top-left toggles Live Photo on/off (with diagonal slash when inactive).
  - Top plate: Knurled zoom wheel centered at x=594 with "ZOOM" factor text performing a 3D vertical flip (`rotation3DEffect`) when orientation shifts between landscape sides; hatch covers removed; wheel smoothly animates to 1.0x on switch to front camera and restores previous zoom on switch to back camera.
  - Top-right deck: Dedicated host-only "End Roll" recessed button (36×48, vertical portrait-baseline text, vertically centered with the zoom wheel at y=63); circular Info button removed. Tapping opens the "End this roll?" confirmation dialog (change 099).
  - Right deck: Circular shutter well (154×154) with silver spherical shutter dome (inner 130×130 dome depresses on tap while outer green ring stays fixed), Flip camera button in recessed well (72×72), and circular analog shots-left dial (83×83, outer frame with 55.865 inner drum, mechanical odometer digit tumblers, rotating face; displays a continuous rotating amber progress arc around the 83×83 rim during sync with a gentle sync pulse and single sharp mechanical decrement snap, change 058).
  - Legacy bottom controls shelf removed.
- Live preview shows the roll's filter in real time (Cinematic 400 B&W = Noir, 200 Color Print = Digicam, change 016); no filter switching on this screen
- Knurled zoom wheel (172×44, look from 007; refactored in change 060):
  - Back camera range: 0.5× (phones with ultra wide) or 1.0× up to 4.0× (36 discrete steps in 0.1× increments via `ZoomStop`)
  - Drag **left** to zoom in, drag **right** to zoom out; ribs translate in 1:1 discrete steps (every 6.0 pt of drag translation) across `-60°` to `+60°`
  - Ratchet tick haptic (`HapticService.playRatchetTick()`) on each discrete 0.1× step; silent hard endstops at min and max (zero haptic pulses when dragging against a reached boundary)
  - No tap-to-step or tap-to-jump gestures on the wheel
  - Follows zoom from Camera Control; front camera: fixed 1.0×, wheel disabled
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
- Envelope: cutting mat (teal mat for every stage; Figma's olive mat on 1323:41482 not used [Open]), closed kraft envelope rotated −3°, paper label: roll name (Architects Daughter 28) and "1 photo" / "N photos" (Architects Daughter 16; the photos on this phone, no "/24"), updating as photos arrive (can lag a little behind friends' uploads [Open], see tech.md End Roll sync); translucent dashed tear-guide pill overlay (`285 × 20` pt `#D9D9D9` at 60%, Figma 1335:66589, change 075) with idle shimmer and sliding finger cue while unlocked; while photos are missing (photos on this phone < the roll's shots used, first 10 s): "Printing your photos…" under the envelope (Architects Daughter 16, `Paper.light` with a soft shadow), the tear strip only gives a little and springs back with gentle lock wiggle/nudge if tapped or dragged early, each new photo bounces the envelope and rolls the count up (numeric text); when all are in: "Your photos are ready!" for 2.5 s [Draft text] (change 024), then `"Swipe or tap to open"` until torn (change 075). Reduce Motion: no bounce, rolling, shimmer, or wiggle
- Tear: swipe across the top flap strip (about 110 pt or a fast swipe, progressive peel + step haptics every ~`20` pt, change 075) OR tap anywhere on the unlocked envelope; the strip flies off, heavy haptic; the photos fly out to the mat one after another and the envelope fades
- Scattered: photos with a 1.5 pt white border, long side 150 pt, ±14° rotation, overlapping; drag moves a photo and brings it to the front; photos arriving later land on the mat
- "Tidy Up" (top right, 44 pt pill) → 2-column grid on Kraft light-active, 175 × 233 cells, 18 pt corners, capture time badge ("16:45"), scrolls; the button then reads "Scatter"
- "Start Scrapbook" (bottom, large pill) on both views → scrapbook editor
- Photo detail: 40% black dim, photo with a 5 pt white border (Live Photo plays on press), "Save" pill + share circle below it; tap outside closes. Save toast: "Saved to Photos" / "Couldn't save. Allow Rèlic to add photos in Settings." (uses `AppBrand.name`, change 134)

## Screen: Profile tab (Library) [Locked]
Figma nodes 1300:36485 (empty state), 1300:36434 (bookshelf), 1300:36781 (settings); changes 044, 088, 103, 122, 125.
- Root full-width `Kraft.lightActive` background (`ZStack` with `.ignoresSafeArea()` and `.frame(maxWidth: .infinity)` so no white side gaps).
- Header: `120` pt circular avatar (`ProfileAvatarView`), centered `20` pt Bold name, and centered `13` pt italic bio (`"No bio yet"` when empty). Top-right circular `"⋯"` menu (`ellipsis.circle.fill`): `"Profile Settings"` (gear) → `AppRoute.editProfile`; `"Share Profile"` (disabled / no-op stub).
- Bookshelf (`1300:36434`): rows of up to 12 vertical book spines standing on wooden shelf planks (`Assets.xcassets/Profile/WoodenShelfPlank`). Each spine is the scrapbook's spine from Edit Cover (spine art in the cover color with its pencil, stickers and text; change 103); an undecorated spine shows only the fallback color. Only saved scrapbooks (locked by Save Scrapbook) are on the shelf; the others are in Resume Editing (change 125). Tap opens scrapbook editor, long-press context menu offers "Delete" (`"Delete this scrapbook?"` / `"Its photos on this phone are deleted too."`).
- Empty state (`1300:36485`): `"Your bookshelf is waiting!"`, wooden shelf plank, and `"Create Roll"` primary pill button (`Brand.primary` fill, `Paper.lightHover` 22 pt Bold text, width 217, height 52) → `AppRoute.createRollSetup`.

## Screen: Profile Settings [Draft]
Figma node 1300:36781 (changes 044, 088)
- `Kraft.lightActive` background; native navigation bar toolbar with `"Cancel"` leading, `"Profile Settings"` inline title, and `"Save"` trailing
- `120` pt circular avatar with bottom-right `camera` badge opening `PhotosPicker` (and `"Remove Photo"` when set)
- Card 1 (`Paper.lightActive`, `1` pt `Brand.primary` border, radius `26`): editable `"Name"` (blank preserves existing name) and `"Bio"` rows
- `"Private Information"` header + Card 2: read-only `"Email"` row (`"Not provided"` fallback when `nil`)
- Bottom `"Log Out"` pill (Figma `1515:29898`, change 088): solid dark-red pill (`#681111` fill, `DSColor.Kraft.light` 18 pt Semibold text, height 52) → confirmation `"You'll need to sign in again to access your account."` with `"Log Out"` (destructive) and `"Cancel"`

## Screen: Scrapbook (book view + spread editor) [Open] (design in progress)
Book view and spread editor from Figma (change 025); tools from the camera POC (change 022).
- Book view (change 025, Figma 1444:23742 / 1518:30319; change 107 for iPad): Workbench desk (`DeskWood`) and green cutting mat with grid, rulers 1–9 (drawn from the Figma layers); open book with the current spread (cover in the scrapbook's cover color with the cover grain and inner shadow, change 103); each page shows the items of both pages of its spread in one layer order, cut at its own edges, so an item across the gutter is whole on the open book and its part on a turning page turns with it (change 104); drag the book to turn a page in 3D around the spine (follows the finger, falls over past a third or with a flick); past the last spread comes a blank spread that isn't saved, with "Need more space?" and a dark "+ Add page" pill on the right page (Figma 1662:27296): "+ Add page" adds two empty pages there and is the only way on (that spread's right page doesn't turn), swiping back adds nothing, a finished or locked book has none (change 121); tap zooms the spread into the edit view (matched zoom); Back (top left) → confirmation card with washi tape and star (Figma 1533:25816): "Leave the scrapbook?" / "Your changes are saved. You can come back and continue editing anytime.", Cancel / Go to Home (the Craft tab, also when opened from another tab) (change 121); round ✓ at the top right (Figma 1518:30319) instead of the Done button: the star card "Done editing your pages?" / "Nice work! Now let's finish it with a cover.", Cancel / Edit Cover (Figma 1708:45425); welcome card once per scrapbook on this phone (Figma 1444:23742): happy star, "Welcome to your scrapbook!" / "Tap the scrapbook to start editing. Add photos, get creative, and make it yours together.", no buttons, a tap dismisses it; a saved or done book: tap → the pages read only (no tray, Editing Progress, Undo, Redo; items not touchable), X back, zoom button, two-finger zoom; on its last spread the right page doesn't lift (change 125); tooltip "More pages to fill!" / "You can swipe to another page and decorate it too." with X, once per user. On iPad, `bookScale` and `bookMatScale` scale the book and cutting mat generously to fit both portrait and landscape viewports with clean clearance above PageHintTooltip (change 107).
- Edit view portrait (1274:33449 / 1537:25210 / 1536:24095): dark `Brand.primary` background; top bar X (back to the book), zoom (spread → left → right, icon shows the state; a zoomed page fills the screen width, an item across the gutter is cut at the screen edge and shows its part on the zoomed page, only the zoomed page's items take touches, change 104), Who's here, Undo, Redo (disabled at the latest change); round white buttons with the ink offset shadow; "Live Photos paused in Low Power Mode" under the spread; the keyboard doesn't shrink the pages; two-finger zoom on the pages (spread, left, right; also the landscape spread): pinch on the paper zooms 1×–5× around the fingers and pans, the pages stay zoomed and spread over the dark area around them under the buttons and the tray, double tap on empty paper or a zoom-button / screen change goes back to 1×; pinch on an item still resizes it; with Pencil one finger draws and two fingers zoom (change 114)
- Edit view landscape (1563:30642 / 1563:30756 / 1563:31649 / 1563:30868 for iPhone; Figma 1547:29247 for iPad, change 107):
  - iPhone: only on the spread (zoom hidden); buttons in a column on the notch / Dynamic Island side, following how the phone is turned (Dynamic Island left: buttons left, tray right, 1563:31649; Dynamic Island right: buttons right, tray left, 1563:30868; switches when the phone is turned over, change 113) (Undo, Redo, Who's here at the top, X at the bottom); the tool tray stands on the other side, closed button upright at the bottom, swipe toward the screen edge closes it; the Pencil and eraser size panels sit at the bottom beside the tray, about 60 pt above the screen's bottom edge, clear of the home indicator (change 113)
  - iPad Landscape (Figma 1547:29247, change 107): full-height edge-to-edge spread framing (`ignoresSafeArea`) with pages unclipped (`pageWidth = min(width/2, fullHeight * 3 / 4)`), top bar (`X` top-leading; `Who's here`, `Undo`, `Redo` top-trailing, no Zoom toggle), and PencilKit-style dockable floating tool tray.
  - iPad Portrait (change 107): top bar with Zoom toggle (`spread -> left -> right`), dark `Brand.primary` margins framing the spread, and PencilKit-style dockable floating tool tray.
- Who's here (1516:23450): sheet titled "Editing Progress" (change 125) with X; "ON THIS PAGE" (this spread, me first as "Name (You)") and "ON OTHER PAGES" with "Page N"; avatar photo or colored circle with initial
- Cover screen (change 026, Figma 1515:29509 host / 1563:33405 participant / 1563:33594 finished; change 107 for iPad): cutting mat with 20 / 100 pt grid and ticked edges (drawn from the Figma layers), the closed front cover; ‹ at the top left for the host and participants who aren't done: back to the pages, editing again (change 125); top right Editing Progress and "⋯" (Save as Video and Share shown, no action yet [Open]); bottom buttons: host Edit Cover + Save Scrapbook, participant Edit Cover + Done Editing, finished Back to Home (capped to 358 pt on iPad); tap the book to read it. On iPad, `coverScale` scales the cover prominently to fill both portrait and landscape viewports with clean clearance above the bottom buttons (change 107).
- Edit Cover (1444:23793 front, 1515:27196 spine): no title; top right on both sides Editing Progress, Undo, Redo, ✓ (back to the cover screen); ‹ at the top left of the spine back to the front (change 121); cover blue by default (`#303D6E`, from the Figma book 1444:23742) until someone picks a color, then the picked color (white included) (change 103), with the Figma material (texture grain kept over any color, spine hinge, inner shadow); tray open and fixed (centered, no scrolling, doesn't fold away) with this side's tools; swiping the second tray down puts the tool away (change 103); color picker button above the tray (system picker in a sheet); a dark "Edit book spine →" pill under the top bar on the front opens the spine (change 121); cover text in Architects Daughter, spine text upright and resizable up to the spine's width; stickers on the spine start at 60% of its width and can grow to its width (change 103); undo / redo cover both sides' items and the cover color (one step per opening of the color picker), the history starts empty each time Edit Cover opens (change 121)
- Editing Progress (1563:33166): sheet with X, "Done Editing" / "In Progress", profile photos (mine from my profile, friends' from presence or the room)
- Cards (star + washi, 1563:33117 / 1563:33675 / 1563:33475): "Ready to close the scrapbook?" (Keep Editing / Save Scrapbook), "Scrapbook Complete!" (View Bookshelf), "Nice Work!" (Got It)
- Pages: Figma paper (`#F6F1E7`, faint r 0.75 pt dots every 16 pt at any page size, a little smaller and denser than Figma's 22 pt by user decision (change 127), inner shadow that marks the gutter); new items go to the page last touched (zoomed: that page); items stay on a zoomed page; on the spread an item across the gutter stays whole over both pages (the two pages are clipped together at the outer edges) and moves to the page its center lands on when dropped (change 104)
- Tool tray (change 022, Figma 1306:48941 / 1306:48947; change 107 for iPad):
  - iPhone: round red leather button (96 pt) at the bottom left → full-width main tray (106 pt, stitching inset 8 pt) with Scissors, Pencil, Stickers, Photos, Washi, Letters, Text; a tool opens a second tray overlapping 18 pt above; tapping the same tool or an empty spot closes it; swipe down (landscape: toward the screen edge) on the second tray puts only the tool away, on the main tray folds both back and turns the tool off (change 127); light haptic per tool. The closed button sits in one of two corners, like Freeform (change 127): bottom left / right in portrait, bottom / top of the tray's side in landscape; a drag slides it and it settles in the nearer corner (or the flicked one); a closing swipe leaning more than 12 pt to one side sends it to that corner; a turn of the phone puts it back in its default corner (left / bottom).
  - iPad (PencilKit-style floating tray, change 107): main tray and all sub-trays share a compact `500` pt rounded stitched leather pill (`trayPillWidth`) with horizontal scroll clipping inside the stitched border. Defaults to bottom-center with top grabber handle; draggable to dock on `.bottom` (0°), `.leading` (+90° along left edge), or `.trailing` (-90° along right edge); collapses to a corner circle button (`.bottomLeading` or `.bottomTrailing`) when swiped toward its docked edge or dragged into a bottom corner.
- Items: photos (white print frame), stickers, letters, text, washi, drawing layers; tap selects and brings to front; both pages of a spread share one layer order: selecting, Bring to Front, new items and items moved to the other page go in front of both pages, Send to Back behind both pages, and nothing else is reordered (change 104); drag / pinch / rotate (snaps to 0° within ±3°); a selected item (not drawing layers) has a bottom-right corner handle to resize / rotate with one finger; dragging any movable item reveals a floating animated trashcan (`ScrapbookTrashCanView`) above the bottom tray whose lid springs open on hover (item scales down/dims) and removes immediately on drop (stickers return to their sheet slot; uncut photos—or cut photos once all remaining pieces are removed—return to `PhotoTray`; leftover cut pieces discard only that piece); double tap: photo full screen, text edit; long-press menu: Bring to Front, Send to Back, Turn Off / On Motion (Live), Edit Text (text), Remove from Page; max 40 items per page, drawing layers included (change 062)
- Photos tray (1306:49859): this roll's photos as small polaroids keeping their own ratio (long side 52 pt, ±6°, newest left, Live badge); single-use across all pages of the scrapbook (shared live with collaborators) until removed; tap adds, drag up drops; empty: "Photos from this roll appear here." (empty roll) or "All photos from this roll are on the scrapbook." (all placed) (change 062)
- Stickers tray (1306:50103 / 1306:54411): Travel and Fun (27) sheets; the sheet opens over the pages on screen (83% width) over a dimmed spread, a sticker sticks to the page it's dropped on; peel–drag–stick, drop outside the sheet sticks, the sheet fades to 40% while dragging; single use per sheet synced live across collaborators (removed stickers return to their exact slot on the sheet unless reused on another page), "Take a New Sheet" synced via `.stickerSheetReset` (change 062)
- Scissors: first in the main tray; as the POC (drag to cut, long press to move—also activates the floating drag-to-trash target for leftover cut pieces—two fingers to pinch / rotate, scissors image, haptics); only photos are cut (change 062). On the two-page view one pair of scissors covers both pages and a cut reaches the photos of both pages front first, so a photo across the gutter can be cut on either side (change 126). Auto-complete (change 126): a stroke that enters a photo and stops inside it is continued straight to the edge; a rough loop inside a photo (at least 30% of the photo long, ending within 20% of its start) closes itself: its inside becomes a piece and the rest keeps a hole (one polygon with a hidden bridge, drawn as two rings); a stroke that never touches a photo cuts nothing; "page full" shows only when the stroke was on a photo of that page
- Pencil (1306:50774, 1144:25595): Pen, Brush, Marker, Crayon, Fountain pen, Eraser (erases only where the finger passes, `.bitmap`), Pick color (the whole circle opens the system color picker in a sheet, change 114); tapping the active tool opens 5 sizes + opacity 10–100%, the eraser its own 5 circle sizes without opacity (Figma 1628:48361, change 114); in portrait the panel fades in right above the picked tool, like Notes (change 114); finger and Apple Pencil; no reed pen; on the spread one canvas covers both pages so a stroke can cross the gutter; each stroke is stored in the layer of the page it starts on (change 104); strokes are undone / redone with the top bar, one step per stroke
- Washi (1306:49648 / 1306:56097): 4 rolls; pull on the page, straight tape with torn ends, haptic ticks, lift to tear; width 16% of the page, minimum 10%, opacity 0.88
- Letters (1306:49157): A–Z, 0–9, reusable; taps within 3 s line up to the right and wrap; drag up drops; height 12% of the page width
- Text: typing screen over the dimmed page, 7 colors, Done; system serif semibold; empty text isn't added
- Hints, once per scrapbook (first time the tool is on) [Draft text]: Scissors "Drag across a photo to cut. Long press to move.", Pencil "Draw with your finger." (iPhone) / "Draw with your finger or Apple Pencil." (iPad), Washi "Put your finger on the page and pull to stick washi tape"; on the two-page view the hint shows once, centered over both pages (change 103)
- Toast "This page is full"

## Design system [Locked]
Figma page "Design System #2" (628:4011), Atoms and Molecules only. Code: `Core/DesignSystem/` (`DS` prefix). Existing `ScrapTheme`, `OffsetPillButtonStyle` stay; `BackCircleButton` deprecated in change 122 in favor of native Apple navigation bars and SF Symbol components.

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
- Workbench interactive & iPad landscape additions (changes 104, 105, 106): `Workbench/DeskToolboxBase` + 8 loose tool sprites (`DeskToolboxRuler`, `DeskToolboxPencils`, `DeskToolboxCutter`, `DeskToolboxScissors`, `DeskToolboxEraser`, `DeskToolboxTapePink`, `DeskToolboxTapeBlue`, `DeskToolboxNotes`); `Workbench/DeskWoodLandscape`, `Workbench/DeskBookBottomLandscape` (`1563:34278`); `Workbench/DeskFilmRollYellow`, `Workbench/DeskFilmRollGreen`, `DeskFilmRollRed` (`1235:21168`).
- DeskCollection (folder `DeskCollection/`, changes 104, 106): folder `Back`, `Flap`, and `FolderEdgeHighlight` layers for Burgundy/Kraft/Navy (`1537:25855`), `ToolboxEmptyNotebook/Pencil/Ruler/Scissors/Starburst/PhotoBack/PhotoFront` (`1537:25830`), and `RollEmptyLeader`, `RollEmptyStarLeft`, `RollEmptyStarTop`, `RollEmptyStarRight` (`1537:25997`).
- DeskDisposableCamera, DeskDisposableCameraBack (catalog root, reusable): Workbench camera front and back (change 110)
- Flow headers: CreateRollHeaderDecoration, ShareRoomHeaderDecoration
- FilterCanisterBW (725:6301), FilterCanisterColor (725:6480): Choose filter
- Roll Reveal (folder `Reveal/`, change 021): RevealCuttingMat (@3x PNG, export of 1323:41569) and the envelope as SVG layers (EnvelopeBody, EnvelopeTextureA/B, EnvelopeFlap, EnvelopeFlapLine, EnvelopeLeftEdge, EnvelopeBottomFold); the body's SVG shadow is not drawn by iOS and is clipped in Figma anyway
- Loading (folder `Loading/`, change 024): FilmStripAmber (SVG, preserves vector, MID-Fi "Vintage Amber Film Strip" 1235:20885, Figma background rect removed); reuses FilterCanisterBW / FilterCanisterColor
- Scrapbook tool tray (change 022, copied from the camera POC): `Tray/` (tray-tool-*, tray-pencil-*, tray-washi-1…4, tray-pen-size-1…5), `Letters/` (letter-A…Z, letter-0…9, SVG), `Scrapbook/` sticker-fun-* (27) and sticker-sheet-fun
- Book view (folder `BookView/`, change 025): ScrapbookZoomSpread / ZoomLeft / ZoomRight and ScrapbookPeople (SVG glyphs from the Figma buttons, background removed), BookConfirmWashi (SVG), BookConfirmStar (@3x PNG cut from the Figma image, transparent); reuses DeskWood; BookCoverTexture (neutral grain made from the Figma cover image, change 026), BookConfirmStarWink (@3x PNG from the Figma image)
- Profile (folder `Profile/`, change 088): `WoodenShelfPlank` (wooden bookshelf plank PNG, Figma 1515:31687 / 1300:36435) and Figma book spine artwork.
- AppIcon (`AppIcon.appiconset`, change 134 + dark variant): universal `1024×1024` opaque PNG (`AppIcon.png`, film strip and blue scissors flattened onto `#F9F5ED`) for Any Appearance and `1024×1024` Dark variant (`Icons-Relic-iOS-Dark-1024@1x 2.png`) for iPhone and iPad.

Note: designs are still in progress, so treat Figma-derived details as [Draft] until marked Locked.
