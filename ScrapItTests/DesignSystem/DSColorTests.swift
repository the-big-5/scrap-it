import Testing
@testable import ScrapIt

@MainActor
struct DSColorTests {
    static let expected: [(String, DSColorToken, String)] = [
        ("Brand.primary", DSColor.Brand.primary, "#2A241F"),
        ("Brand.secondary", DSColor.Brand.secondary, "#EBCB6B"),
        ("Brand.tertiary", DSColor.Brand.tertiary, "#6B2430"),
        ("State.info", DSColor.State.info, "#2F80ED"),
        ("State.success", DSColor.State.success, "#27AE60"),
        ("State.warning", DSColor.State.warning, "#E2B93B"),
        ("State.error", DSColor.State.error, "#E50935"),
        ("Camera.leather", DSColor.Camera.leather, "#9A5531"),
        ("Camera.camera", DSColor.Camera.camera, "#D2D0CB"),
        ("Camera.cognac", DSColor.Camera.cognac, "#6E3A20"),
        ("Paper.light", DSColor.Paper.light, "#FEFEFD"),
        ("Paper.lightHover", DSColor.Paper.lightHover, "#FEFDFB"),
        ("Paper.lightActive", DSColor.Paper.lightActive, "#FCFBF8"),
        ("Paper.normal", DSColor.Paper.normal, "#F6F1E7"),
        ("Paper.normalHover", DSColor.Paper.normalHover, "#DDD9D0"),
        ("Paper.normalActive", DSColor.Paper.normalActive, "#C5C1B9"),
        ("Paper.dark", DSColor.Paper.dark, "#B9B5AD"),
        ("Paper.darkHover", DSColor.Paper.darkHover, "#94918B"),
        ("Paper.darkActive", DSColor.Paper.darkActive, "#6F6C68"),
        ("Paper.darker", DSColor.Paper.darker, "#565451"),
        ("Kraft.light", DSColor.Kraft.light, "#FCFBF9"),
        ("Kraft.lightHover", DSColor.Kraft.lightHover, "#FBF9F5"),
        ("Kraft.lightActive", DSColor.Kraft.lightActive, "#F7F2EB"),
        ("Kraft.normal", DSColor.Kraft.normal, "#E4D6BF"),
        ("Kraft.normalHover", DSColor.Kraft.normalHover, "#CDC1AC"),
        ("Kraft.normalActive", DSColor.Kraft.normalActive, "#B6AB99"),
        ("Kraft.dark", DSColor.Kraft.dark, "#ABA18F"),
        ("Kraft.darkHover", DSColor.Kraft.darkHover, "#898073"),
        ("Kraft.darkActive", DSColor.Kraft.darkActive, "#676056"),
        ("Kraft.darker", DSColor.Kraft.darker, "#504B43"),
        ("Green.light", DSColor.Green.light, "#EDF2ED"),
        ("Green.lightHover", DSColor.Green.lightHover, "#E4EBE4"),
        ("Green.lightActive", DSColor.Green.lightActive, "#C8D6C7"),
        ("Green.normal", DSColor.Green.normal, "#4D7A49"),
        ("Green.normalHover", DSColor.Green.normalHover, "#456E42"),
        ("Green.normalActive", DSColor.Green.normalActive, "#3E623A"),
        ("Green.dark", DSColor.Green.dark, "#3A5C37"),
        ("Green.darkHover", DSColor.Green.darkHover, "#2E492C"),
        ("Green.darkActive", DSColor.Green.darkActive, "#233721"),
        ("Green.darker", DSColor.Green.darker, "#1B2B1A"),
        ("Component.field", DSColor.Component.field, "#EBE2D3"),
        ("Component.surface", DSColor.Component.surface, "#FFFDF8"),
        ("Component.placeholder", DSColor.Component.placeholder, "#6E6458"),
        ("Component.textSecondary", DSColor.Component.textSecondary, "#5E5449"),
        ("Component.disabledText", DSColor.Component.disabledText, "#8A7F73"),
        ("Component.disabledBackground", DSColor.Component.disabledBackground, "#E9E1D3"),
        ("Component.inputError", DSColor.Component.inputError, "#A8382A"),
        ("Component.fillTertiary", DSColor.Component.fillTertiary, "#767680"),
        ("Component.labelTertiary", DSColor.Component.labelTertiary, "#3C3C43"),
        ("Component.toggleOffLabel", DSColor.Component.toggleOffLabel, "#B3B3B3"),
        ("Component.white", DSColor.Component.white, "#FFFFFF"),
    ]

    @Test func hexValuesMatchFigma() {
        for (name, token, hex) in Self.expected {
            #expect(token.light.hexString == hex, "\(name)")
        }
    }

    @Test func translucentTokensKeepFigmaAlpha() {
        #expect(DSColor.Component.fillTertiary.light.alpha == 0.12)
        #expect(DSColor.Component.labelTertiary.light.alpha == 0.3)
        let opaque = Self.expected.filter { !["Component.fillTertiary", "Component.labelTertiary"].contains($0.0) }
        for (name, token, _) in opaque {
            #expect(token.light.alpha == 1, "\(name)")
        }
    }

    /// Dark mode is [Open]; until designed, dark equals light.
    @Test func darkEqualsLight() {
        for (name, token, _) in Self.expected {
            #expect(token.dark == token.light, "\(name)")
        }
    }
}
