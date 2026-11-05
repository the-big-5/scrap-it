# Flows
## F1: Sign in [Locked]
1. User opens app
2. Not signed in: sees Welcome screen, taps "Sign in with Apple"; Apple verifies the Apple Account (Face ID / passcode). Only on success is the profile created (or loaded). Requested data: full name only
3. Already signed in: the saved Apple user ID is checked with Apple on launch. Authorized and online → straight to Home. Revoked, not found, check error, or offline → Welcome
4. Sign out (temporary, on Profile tab until the Profile design is ready): returns to Welcome; local data is kept
Edge cases:
- Cancel: stay on Welcome, no message
- Sign-in fails (including no Apple Account on the device): stay on Welcome with an error message
- No network: cannot sign in and cannot enter; Welcome shows an offline message and the sign-in button is disabled
- First launch: Welcome
- Apple ID revoked while the app is running: caught on the next launch (no live sign-out)

## F2: Join a Roll [Locked]
1. Friend opens Join Roll and scans the host's QR code, enters the 6-character roll code, or opens the share link
2. Friend joins the roll; late joining is allowed while the roll lasts
3. Codes and links stay valid until the roll ends
Edge cases: app not installed [Open]

## F3: Roll (real-time shared capture session) [Locked]
1. Host creates a roll: name, number of shots (24, 36, 48 or 72) and a filter
2. Host shares the lobby (QR code, roll code, share link) and taps Start Roll
3. Everyone takes photos (still and Live Photo) at the same time in-app. Nobody, including the host, sees others' photos during the roll; everyone sees only the remaining shots and who is currently in the roll
4. One shared pool of shots; any person's photo uses one shot
5. Roll ends when the shots run out OR the host ends it manually
6. Photos are saved into a new shared scrapbook (others' photos become visible here)
Edge cases:
- Network lost mid-roll: photos queue locally and sync later
- Host disconnects: host role passes to the next participant
- Last-shot race: first write wins; the other photo is dropped and that user is told the roll finished

## F4: Profile shelf [Draft]
1. User opens profile → sees row of scrapbook covers on a shelf
2. Taps a cover → opens scrapbook
Empty/loading states: [Open]

## F5: Scrapbook creation [Draft]
1. When a roll ends, a new scrapbook is created showing the captured photos in a basic grid (title, cover photo, created date, photos with captions)
Collaboration rules: [Open]

## F6: Social discovery [Open]
