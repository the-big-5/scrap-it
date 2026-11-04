import SwiftUI
import UIKit

/// An sRGB color value with 8-bit channels, as written in Figma.
struct DSRGBA: Hashable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: Double

    /// `hex` is `0xRRGGBB`.
    init(hex: UInt32, alpha: Double = 1) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
        self.alpha = alpha
    }

    init(red: UInt8, green: UInt8, blue: UInt8, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// `#RRGGBB`, alpha not included.
    var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    var uiColor: UIColor {
        UIColor(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: alpha
        )
    }
}

/// A design system color with a light and a dark value.
/// Usable directly as a `ShapeStyle` (`.foregroundStyle(DSColor.Brand.primary)`), or via `.color`.
struct DSColorToken: ShapeStyle, Hashable, Sendable {
    let light: DSRGBA
    let dark: DSRGBA

    /// Dark mode is [Open]: until designed, the dark value equals the light value.
    init(_ hex: UInt32, alpha: Double = 1) {
        light = DSRGBA(hex: hex, alpha: alpha)
        dark = light
    }

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let value = environment.colorScheme == .dark ? dark : light
        return Color.Resolved(
            colorSpace: .sRGB,
            red: Float(value.red) / 255,
            green: Float(value.green) / 255,
            blue: Float(value.blue) / 255,
            opacity: Float(value.alpha)
        )
    }

    /// Adaptive `Color` for APIs that need a `Color` (e.g. shadows).
    var color: Color {
        let light = light.uiColor
        let dark = dark.uiColor
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}
