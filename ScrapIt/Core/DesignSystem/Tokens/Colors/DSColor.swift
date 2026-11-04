import Foundation

/// Color tokens from Figma "Design System #2" → 01. Colors (node 629:4298), named as in Figma.
enum DSColor {
    enum Brand {
        static let primary = DSColorToken(0x2A241F)
        static let secondary = DSColorToken(0xEBCB6B)
        static let tertiary = DSColorToken(0x6B2430)
    }

    enum State {
        static let info = DSColorToken(0x2F80ED)
        static let success = DSColorToken(0x27AE60)
        static let warning = DSColorToken(0xE2B93B)
        /// Swatch fill (variable `status/error-fg`). The swatch caption says #EB5757 [Open].
        static let error = DSColorToken(0xE50935)
    }

    enum Camera {
        static let leather = DSColorToken(0x9A5531)
        static let camera = DSColorToken(0xD2D0CB)
        static let cognac = DSColorToken(0x6E3A20)
    }

    /// "Paper (Background)" scale.
    enum Paper {
        static let light = DSColorToken(0xFEFEFD)
        static let lightHover = DSColorToken(0xFEFDFB)
        static let lightActive = DSColorToken(0xFCFBF8)
        static let normal = DSColorToken(0xF6F1E7)
        static let normalHover = DSColorToken(0xDDD9D0)
        static let normalActive = DSColorToken(0xC5C1B9)
        static let dark = DSColorToken(0xB9B5AD)
        static let darkHover = DSColorToken(0x94918B)
        static let darkActive = DSColorToken(0x6F6C68)
        static let darker = DSColorToken(0x565451)
    }

    enum Kraft {
        static let light = DSColorToken(0xFCFBF9)
        static let lightHover = DSColorToken(0xFBF9F5)
        static let lightActive = DSColorToken(0xF7F2EB)
        static let normal = DSColorToken(0xE4D6BF)
        static let normalHover = DSColorToken(0xCDC1AC)
        static let normalActive = DSColorToken(0xB6AB99)
        static let dark = DSColorToken(0xABA18F)
        static let darkHover = DSColorToken(0x898073)
        static let darkActive = DSColorToken(0x676056)
        static let darker = DSColorToken(0x504B43)
    }

    enum Green {
        static let light = DSColorToken(0xEDF2ED)
        static let lightHover = DSColorToken(0xE4EBE4)
        static let lightActive = DSColorToken(0xC8D6C7)
        static let normal = DSColorToken(0x4D7A49)
        static let normalHover = DSColorToken(0x456E42)
        static let normalActive = DSColorToken(0x3E623A)
        static let dark = DSColorToken(0x3A5C37)
        static let darkHover = DSColorToken(0x2E492C)
        static let darkActive = DSColorToken(0x233721)
        static let darker = DSColorToken(0x1B2B1A)
    }

    /// Figma variables used by the button and input components.
    enum Component {
        static let field = DSColorToken(0xEBE2D3)
        static let surface = DSColorToken(0xFFFDF8)
        static let placeholder = DSColorToken(0x6E6458)
        static let textSecondary = DSColorToken(0x5E5449)
        static let disabledText = DSColorToken(0x8A7F73)
        static let disabledBackground = DSColorToken(0xE9E1D3)
        /// Variable `color/error`, used by the text field error state.
        static let inputError = DSColorToken(0xA8382A)
        /// Variable `fills/tertiary`: secondary/disabled button background.
        static let fillTertiary = DSColorToken(0x767680, alpha: 0.12)
        /// Variable `labels/tertiary`: disabled button text, toggle off track.
        static let labelTertiary = DSColorToken(0x3C3C43, alpha: 0.3)
        /// Variable `Miscellaneous/Toggle/AX Label - Off`.
        static let toggleOffLabel = DSColorToken(0xB3B3B3)
        /// Variable `Grays/White`.
        static let white = DSColorToken(0xFFFFFF)
    }
}
