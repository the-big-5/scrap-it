# 003: Design system (Atoms + Molecules) from Figma
Status: Approved

## Why
The app has no shared design system yet. Colors and button styles are hand-picked in `ScrapTheme` and `OffsetPillButtonStyle`. Figma "Design System #2" now defines Atoms (colors, typography) and Molecules (buttons, inputs & controls). This change builds those as reusable SwiftUI tokens and components in `Core/DesignSystem/` so later changes can apply them to screens.

Source: `Design System Spec.md` (user-provided), adapted to `spec/tech.md`. Where the two disagree, tech.md wins (see Decisions).

## Touches
tech.md (Code structure: `Core/DesignSystem/`, no rule changes), ui.md (ADDED: Design system section), flows.md (no changes)

## Figma source
File key `ujlkuWobqxyvtQwh5plhGF`, page "Design System #2" (628:4011)

| Layer | Section | Node |
| :--- | :--- | :--- |
| Atoms | 01. Colors | 629:4298 |
| Atoms | 02. Typography, Headings (SF Pro) | 629:5503 |
| Atoms | Body (SF Pro) | 629:5466 |
| Atoms | Body (Architects Daughter) | 643:930 |
| Molecules | 08. Buttons | 629:5343 |
| Molecules | 06. Inputs & Controls | 629:5426 |

Not used: "Template Reference" (629:4404) and "Organism" (Navigation, 647:3958).

## Changes
- ADDED: color tokens (`DSColor`), following Figma names
  - Brand: primary `#2A241F`, secondary `#EBCB6B`, tertiary `#6B2430`
  - State: info `#2F80ED`, success `#27AE60`, warning `#E2B93B`, error `#E50935` (the swatch's fill variable `status/error-fg`; its caption says `#EB5757`, see Open)
  - Input error: `#A8382A` (Figma variable `color/error`, used by the text field error state), kept as its own token `inputError`
  - Camera: leather `#9A5531`, camera `#D2D0CB`, cognac `#6E3A20`
  - Paper scale: light `#FEFEFD`, lightHover `#FEFDFB`, lightActive `#FCFBF8`, normal `#F6F1E7`, normalHover `#DDD9D0`, normalActive `#C5C1B9`, dark `#B9B5AD`, darkHover `#94918B`, darkActive `#6F6C68`, darker `#565451`
  - Kraft scale: light `#FCFBF9`, lightHover `#FBF9F5`, lightActive `#F7F2EB`, normal `#E4D6BF`, normalHover `#CDC1AC`, normalActive `#B6AB99`, dark `#ABA18F`, darkHover `#898073`, darkActive `#676056`, darker `#504B43`
  - Green scale: light `#EDF2ED`, lightHover `#E4EBE4`, lightActive `#C8D6C7`, normal `#4D7A49`, normalHover `#456E42`, normalActive `#3E623A`, dark `#3A5C37`, darkHover `#2E492C`, darkActive `#233721`, darker `#1B2B1A`
  - Component colors (Figma variables used by buttons/inputs): field `#EBE2D3`, surface `#FFFDF8`, placeholder `#6E6458`, textSecondary `#5E5449`, disabledText `#8A7F73`, disabledBackground `#E9E1D3`
  - Dark mode: every token has a dark value equal to its light value for now
- ADDED: typography tokens (`DSTypography`) and modifier `.dsTypography(_:)`
  - Headings (SF Pro, line height 1.1×): h1 56/61.6, h2 48/52.8, h3 40/44, h4 32/35.2, h5 24/26.4, h6 20/22
  - Body (line height 1.4×), each in bold + regular: large 20/28, medium 18/25.2, normal 16/22.4, small 14/19.6
  - Two body families: SF Pro and Architects Daughter. Architects Daughter "bold" uses the Regular file (only weight available)
  - Fixed point sizes as in Figma (no Dynamic Type scaling for now)
- ADDED: font file `ArchitectsDaughter-Regular.ttf` + `OFL.txt` in `Core/DesignSystem/Fonts/`, registered in code at launch (`CTFontManagerRegisterFontsForURL`), not via `UIAppFonts`
- ADDED: elevation token (`DSElevation`): one level, copied from the existing `OffsetPillButtonStyle` shadow (solid `primary` capsule offset y 5, y 2 when pressed). Modifier `.dsElevation(_:)`
- ADDED: button molecules (`DSButtonStyle` / `DSButton`)
  - Variants: primary, secondary, tertiary, disabled
  - Sizes: small 32, normal 44, large 52; optional full-width
  - Padding rule: horizontal 5× font size, vertical 1× font size (full-width: horizontal fills width)
  - Label font: as in the Figma Button component (722:887), which uses SF Pro Semibold (590): small 14, normal 16, large 18 (see Open)
  - Icon button 44 (primary, secondary, tertiary, disabled) and back circle button (3 sizes)
- ADDED: input & control molecules
  - `DSTextField`: states initial, focused, error (with error message); kinds plain, password (show/hide eye), search (magnifier + clear), caption (multi-line)
  - `DSRadio`, `DSToggle`, `DSCheckbox`
- ADDED: ui.md section "Design system" (written at merge step)

## Tasks
- [x] Create `Core/DesignSystem/Tokens/` (Colors, Typography, Elevation), `Core/DesignSystem/Components/` (Button, Input), `Core/DesignSystem/Fonts/`
- [x] `DSColor`: all tokens listed above, each with light + dark value (dark = light)
- [x] `DSTypography` + `.dsTypography(_:)`: all heading and body tokens, both body families, line height via line spacing
- [x] Copy `ArchitectsDaughter-Regular.ttf` and `OFL.txt` from `~/Downloads/Architects_Daughter/` into `Core/DesignSystem/Fonts/`; add a font registrar called once at app launch; app must not crash if registration fails (fall back to SF Pro)
- [x] `DSElevation` + `.dsElevation(_:)` with the one level above
- [x] `DSButtonStyle` / `DSButton`: 4 variants × 3 sizes, full-width option, icon button, back circle button; pressed and disabled states
- [x] `DSTextField` (4 kinds × 3 states), `DSRadio`, `DSToggle`, `DSCheckbox`
- [x] Read exact values per component from Figma (read-only `get_design_context` / `get_variable_defs`); do not invent values. If a value is missing, stop and ask
- [x] `#Preview` for every component showing all variants and states
- [x] Accessibility basics: VoiceOver labels on icon-only buttons and controls, minimum 44pt tap target
- [x] Tests (Swift Testing, in `ScrapItTests/`): color token hex values, typography sizes and line heights, font registration succeeds, contrast check for text-on-background pairs used by the components (report pairs below WCAG AA; do not change colors)
- [x] `xcodebuild` (iOS Simulator): `BUILD SUCCEEDED` and all tests pass
- [x] Final check: no existing screen looks or behaves differently

## Out of scope
- Applying the new tokens/components to any existing screen (separate change, e.g. 004)
- Changing or deleting `ScrapTheme`, `OffsetPillButtonStyle`, `BackCircleButton` or any other existing file
- Real dark-mode colors
- Dynamic Type scaling
- Elevation levels beyond the one copied level
- Organisms (navigation, tab bar), templates, spacing, grid system, iconography
- A separate Swift Package, macOS support
- `.xcodeproj` settings, Info.plist keys, signing, entitlements
- Third-party libraries
- Writing to Figma
- `swiftui-expert` skill (not used)
- Updating spec files (merge step does that)

## Decisions (from Design System Spec.md vs spec/)
- Location: `Core/DesignSystem/` in the app, not a Swift Package (tech.md Code structure [Locked]; a package would touch `.xcodeproj`)
- Platform: iOS 18, iPhone + iPad (tech.md), not iOS 17 / macOS
- Color names follow Figma, not the semantic Background/Content/Brand/Feedback naming from Design System Spec.md
- New types use the `DS` prefix, so they do not clash with the existing `ScrapTheme` and friends. Both exist side by side until a later change migrates screens
- Font registered at runtime to avoid `UIAppFonts` (Never touch `.xcodeproj`)

## Open (to record in spec at merge)
- Dark mode colors [Open]
- Elevation: full level set (Figma has none yet) [Open]
- Which text uses SF Pro vs Architects Daughter [Open], decided when applying to screens

## Figma inconsistencies (recorded, not resolved; Figma is not edited)
- Error color: State "Error" swatch caption says `#EB5757`, but its fill is variable `status/error-fg` `#E50935`; text field error uses `color/error` `#A8382A`. Built as-is (`error` = fill, `inputError` = input) until design decides [Open]
- Font weight: Typography page shows "Bold", but the Button component's text uses variables `Typography/Body/*/Semibold` (SF Pro Semibold, 590). Typography tokens follow the page (Bold); buttons follow the component (Semibold) [Open]
- Ignored: documentation/template styling in Figma variables (`Color - Primary` `#092C4C`, `Gray 3` `#828282`, Inter font, `Color - Bg Light` `#EDF0F5`). Only Atoms/Molecules frames are the source

## Notes
- Change 002 is Approved but not merged; merging is left to the tech lead and does not block this change

## Decisions made during implementation
- Button label weight follows the Figma component: Primary/Secondary/Disabled Regular, Tertiary Semibold (the "all Semibold" line above was inaccurate)
- Button padding follows the component, not the "Button Rules" note: horizontal 10 (small) / 14 (normal, large); tertiary 6 / 8 / 10 with corner radius 10 / 12 / 14
- Disabled is a state, not a variant: any `DSButtonStyle` variant shows the Figma Disabled look under `.disabled(true)`
- Added tokens from Figma variables used by the components: `fillTertiary` (#767680 at 12%), `labelTertiary` (#3C3C43 at 30%), `toggleOffLabel` (#B3B3B3), `white`
- Heading 6 is Medium (510) in Figma; Headings 1–5 are Bold
- Icons are Figma SVGs as template images in `Assets.xcassets/DesignSystem/` (plus, play, check, close, eye-slash, search); back button uses SF Symbol `chevron.backward` as in Figma
- Pressed state is not in Figma: buttons use 0.7 opacity [Open]
- Password field has only the Figma eye-slash icon, used for both shown/hidden [Open]
- Font registration runs once on first use of a handwritten token (not in `ScrapIt.swift`), so no existing file changes
- Small (32pt) buttons and back buttons keep a 44pt tap target by reserving layout space around the visible shape
- Toggle on/off glyphs follow iOS Settings › Accessibility › On/Off Labels
- Tests ran on an iOS 27.1 simulator with `IPHONEOS_DEPLOYMENT_TARGET=26.6` passed on the command line only: the test target's deployment target is 27.2 and no 27.2 simulator is installed. Project settings were not changed

## Implementation findings (not fixed, out of scope)
- Contrast: Toggle off track (labels/tertiary over Paper.normal) is 1.70:1, below 3:1 for UI parts. Recorded as a known issue in `DSContrastTests`. Input placeholder is 4.51:1, just above 4.5
- tech.md says minimum iOS 18, but the app target's deployment target is iOS 26.6 and the test target's is 27.2
- On launch, SwiftData store fails to load: "CloudKit integration requires that all attributes be optional, or have a default value set" (existing models). Tests still pass
