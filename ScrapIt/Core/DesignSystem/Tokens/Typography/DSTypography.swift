import SwiftUI
import UIKit

enum DSFontFamily: Hashable, Sendable {
    case sfPro
    /// Bundled; only a Regular weight exists, so every weight renders as Regular.
    case architectsDaughter
}

enum DSFontWeight: Hashable, Sendable {
    case regular
    case medium
    case semibold
    case bold

    var swiftUI: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }

    var uiKit: UIFont.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}

/// One text style: family, weight, point size and line height, as in Figma.
/// Fixed point sizes for now (Dynamic Type scaling is out of scope).
struct DSTypographyToken: Hashable, Sendable {
    let family: DSFontFamily
    let weight: DSFontWeight
    let size: CGFloat
    let lineHeight: CGFloat

    var font: Font {
        if usesArchitectsDaughter {
            return .custom(DSFontRegistrar.architectsDaughter, fixedSize: size)
        }
        return .system(size: size, weight: weight.swiftUI)
    }

    var uiFont: UIFont {
        if usesArchitectsDaughter, let font = UIFont(name: DSFontRegistrar.architectsDaughter, size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: weight.uiKit)
    }

    /// Extra spacing between lines so that lines sit `lineHeight` apart.
    var lineSpacing: CGFloat {
        max(0, lineHeight - uiFont.lineHeight)
    }

    private var usesArchitectsDaughter: Bool {
        family == .architectsDaughter && DSFontRegistrar.isArchitectsDaughterAvailable
    }
}

/// Typography tokens from Figma "Design System #2" → 02. Typography
/// (Headings 629:5503, Body SF Pro 629:5466, Body Architects Daughter 643:930).
enum DSTypography {
    // Headings: SF Pro, line height 1.1× font size. Heading 6 is Medium in Figma.
    static let heading1 = DSTypographyToken(family: .sfPro, weight: .bold, size: 56, lineHeight: 61.6)
    static let heading2 = DSTypographyToken(family: .sfPro, weight: .bold, size: 48, lineHeight: 52.8)
    static let heading3 = DSTypographyToken(family: .sfPro, weight: .bold, size: 40, lineHeight: 44)
    static let heading4 = DSTypographyToken(family: .sfPro, weight: .bold, size: 32, lineHeight: 35.2)
    static let heading5 = DSTypographyToken(family: .sfPro, weight: .bold, size: 24, lineHeight: 26.4)
    static let heading6 = DSTypographyToken(family: .sfPro, weight: .medium, size: 20, lineHeight: 22)

    // Body: SF Pro, line height 1.4× font size.
    static let largeBold = body(.sfPro, .bold, .large)
    static let largeRegular = body(.sfPro, .regular, .large)
    static let mediumBold = body(.sfPro, .bold, .medium)
    static let mediumRegular = body(.sfPro, .regular, .medium)
    static let normalBold = body(.sfPro, .bold, .normal)
    static let normalRegular = body(.sfPro, .regular, .normal)
    static let smallBold = body(.sfPro, .bold, .small)
    static let smallRegular = body(.sfPro, .regular, .small)

    // Body: Architects Daughter. Which text uses it is [Open].
    enum Handwritten {
        static let largeBold = body(.architectsDaughter, .bold, .large)
        static let largeRegular = body(.architectsDaughter, .regular, .large)
        static let mediumBold = body(.architectsDaughter, .bold, .medium)
        static let mediumRegular = body(.architectsDaughter, .regular, .medium)
        static let normalBold = body(.architectsDaughter, .bold, .normal)
        static let normalRegular = body(.architectsDaughter, .regular, .normal)
        static let smallBold = body(.architectsDaughter, .bold, .small)
        static let smallRegular = body(.architectsDaughter, .regular, .small)
    }

    enum BodySize {
        case large, medium, normal, small

        var size: CGFloat {
            switch self {
            case .large: 20
            case .medium: 18
            case .normal: 16
            case .small: 14
            }
        }

        var lineHeight: CGFloat {
            switch self {
            case .large: 28
            case .medium: 25.2
            case .normal: 22.4
            case .small: 19.6
            }
        }
    }

    static func body(_ family: DSFontFamily, _ weight: DSFontWeight, _ size: BodySize) -> DSTypographyToken {
        DSTypographyToken(family: family, weight: weight, size: size.size, lineHeight: size.lineHeight)
    }
}

private struct DSTypographyModifier: ViewModifier {
    let token: DSTypographyToken

    func body(content: Content) -> some View {
        content
            .font(token.font)
            .lineSpacing(token.lineSpacing)
    }
}

extension View {
    func dsTypography(_ token: DSTypographyToken) -> some View {
        modifier(DSTypographyModifier(token: token))
    }
}

#Preview("Typography") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heading 1").dsTypography(DSTypography.heading1)
            Text("Heading 2").dsTypography(DSTypography.heading2)
            Text("Heading 3").dsTypography(DSTypography.heading3)
            Text("Heading 4").dsTypography(DSTypography.heading4)
            Text("Heading 5").dsTypography(DSTypography.heading5)
            Text("Heading 6").dsTypography(DSTypography.heading6)
            Divider()
            Text("Large Text Bold").dsTypography(DSTypography.largeBold)
            Text("Large Text Regular").dsTypography(DSTypography.largeRegular)
            Text("Medium Text Bold").dsTypography(DSTypography.mediumBold)
            Text("Medium Text Regular").dsTypography(DSTypography.mediumRegular)
            Text("Normal Text Bold").dsTypography(DSTypography.normalBold)
            Text("Normal Text Regular").dsTypography(DSTypography.normalRegular)
            Text("Small Text Bold").dsTypography(DSTypography.smallBold)
            Text("Small Text Regular").dsTypography(DSTypography.smallRegular)
            Divider()
            Text("Large Text Bold").dsTypography(DSTypography.Handwritten.largeBold)
            Text("Large Text Regular").dsTypography(DSTypography.Handwritten.largeRegular)
            Text("Medium Text Bold").dsTypography(DSTypography.Handwritten.mediumBold)
            Text("Medium Text Regular").dsTypography(DSTypography.Handwritten.mediumRegular)
            Text("Normal Text Bold").dsTypography(DSTypography.Handwritten.normalBold)
            Text("Normal Text Regular").dsTypography(DSTypography.Handwritten.normalRegular)
            Text("Small Text Bold").dsTypography(DSTypography.Handwritten.smallBold)
            Text("Small Text Regular").dsTypography(DSTypography.Handwritten.smallRegular)
            Divider()
            Text("Line height check: two lines of body text\nsit 22.4pt apart.")
                .dsTypography(DSTypography.normalRegular)
        }
        .foregroundStyle(DSColor.Brand.primary)
        .padding()
    }
    .background(DSColor.Paper.normal)
}
