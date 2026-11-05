import Foundation
import Testing
@testable import ScrapIt

/// WCAG 2.1 AA contrast for the text/background pairs the components use.
/// Translucent colors are composited over the app background (Paper.normal).
/// Pairs below AA are reported as known issues; colors are not changed here.
@MainActor
struct DSContrastTests {
    struct Pair {
        let name: String
        let foreground: DSRGBA
        let background: DSRGBA
        /// 4.5 for text, 3.0 for icons and UI parts.
        let minimum: Double
    }

    static let page = DSColor.Paper.normal.light

    static func on(_ background: DSColorToken) -> DSRGBA {
        composite(background.light, over: page)
    }

    static let passingPairs: [Pair] = [
        Pair(name: "Primary button label", foreground: DSColor.Component.white.light, background: on(DSColor.Brand.primary), minimum: 4.5),
        Pair(name: "Secondary button label", foreground: DSColor.Brand.tertiary.light, background: on(DSColor.Component.fillTertiary), minimum: 4.5),
        Pair(name: "Tertiary button label", foreground: DSColor.Camera.leather.light, background: page, minimum: 4.5),
        Pair(name: "Primary icon", foreground: DSColor.Paper.normal.light, background: on(DSColor.Brand.primary), minimum: 3),
        Pair(name: "Secondary icon", foreground: DSColor.Brand.primary.light, background: page, minimum: 3),
        Pair(name: "Tertiary icon", foreground: DSColor.Camera.cognac.light, background: on(DSColor.Kraft.normal), minimum: 3),
        Pair(name: "Back chevron", foreground: DSColor.Camera.cognac.light, background: on(DSColor.Component.fillTertiary), minimum: 3),
        Pair(name: "Input value", foreground: DSColor.Brand.primary.light, background: on(DSColor.Component.surface), minimum: 4.5),
        Pair(name: "Input placeholder", foreground: DSColor.Component.placeholder.light, background: on(DSColor.Component.field), minimum: 4.5),
        Pair(name: "Input label", foreground: DSColor.Brand.primary.light, background: page, minimum: 4.5),
        Pair(name: "Error helper", foreground: DSColor.Component.inputError.light, background: page, minimum: 4.5),
        Pair(name: "Clear icon", foreground: DSColor.Component.textSecondary.light, background: on(DSColor.Component.surface), minimum: 3),
        Pair(name: "Checkbox check", foreground: DSColor.Paper.normal.light, background: on(DSColor.Camera.cognac), minimum: 3),
        Pair(name: "Radio / checkbox ring", foreground: DSColor.Component.disabledText.light, background: on(DSColor.Component.surface), minimum: 3),
        Pair(name: "Focused field border", foreground: DSColor.Camera.leather.light, background: on(DSColor.Component.surface), minimum: 3),
        Pair(name: "Toggle on track", foreground: DSColor.Camera.cognac.light, background: page, minimum: 3),
    ]

    /// Known below AA (Figma values, kept as-is). Disabled states are exempt from WCAG and not listed.
    static let lowPairs: [Pair] = [
        Pair(name: "Toggle off track", foreground: on(DSColor.Component.labelTertiary), background: page, minimum: 3),
    ]

    @Test(arguments: passingPairs.indices)
    func pairMeetsAA(_ index: Int) {
        let pair = Self.passingPairs[index]
        let ratio = Self.contrast(pair.foreground, pair.background)
        #expect(ratio >= pair.minimum, "\(pair.name): \(ratio)")
    }

    @Test(arguments: lowPairs.indices)
    func knownLowContrastPair(_ index: Int) {
        let pair = Self.lowPairs[index]
        let ratio = Self.contrast(pair.foreground, pair.background)
        withKnownIssue("\(pair.name) is below WCAG AA (\(String(format: "%.2f", ratio)):1, needs \(pair.minimum):1)") {
            #expect(ratio >= pair.minimum)
        }
    }

    // MARK: - WCAG math

    static func composite(_ color: DSRGBA, over background: DSRGBA) -> DSRGBA {
        func mix(_ fg: UInt8, _ bg: UInt8) -> UInt8 {
            UInt8((Double(fg) * color.alpha + Double(bg) * (1 - color.alpha)).rounded())
        }
        return DSRGBA(
            red: mix(color.red, background.red),
            green: mix(color.green, background.green),
            blue: mix(color.blue, background.blue),
            alpha: 1
        )
    }

    static func luminance(_ color: DSRGBA) -> Double {
        func channel(_ value: UInt8) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)
    }

    static func contrast(_ a: DSRGBA, _ b: DSRGBA) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
