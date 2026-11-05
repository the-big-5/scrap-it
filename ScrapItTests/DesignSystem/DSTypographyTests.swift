import Foundation
import Testing
import UIKit
@testable import ScrapIt

@MainActor
struct DSTypographyTests {
    @Test func headingsMatchFigma() {
        let headings: [(DSTypographyToken, CGFloat, CGFloat, DSFontWeight)] = [
            (DSTypography.heading1, 56, 61.6, .bold),
            (DSTypography.heading2, 48, 52.8, .bold),
            (DSTypography.heading3, 40, 44, .bold),
            (DSTypography.heading4, 32, 35.2, .bold),
            (DSTypography.heading5, 24, 26.4, .bold),
            (DSTypography.heading6, 20, 22, .medium),
        ]
        for (token, size, lineHeight, weight) in headings {
            #expect(token.family == .sfPro)
            #expect(token.size == size)
            #expect(abs(token.lineHeight - lineHeight) < 0.001)
            #expect(abs(token.lineHeight - token.size * 1.1) < 0.001)
            #expect(token.weight == weight)
        }
    }

    @Test func bodyMatchesFigma() {
        let body: [(DSTypographyToken, CGFloat, CGFloat, DSFontWeight)] = [
            (DSTypography.largeBold, 20, 28, .bold),
            (DSTypography.largeRegular, 20, 28, .regular),
            (DSTypography.mediumBold, 18, 25.2, .bold),
            (DSTypography.mediumRegular, 18, 25.2, .regular),
            (DSTypography.normalBold, 16, 22.4, .bold),
            (DSTypography.normalRegular, 16, 22.4, .regular),
            (DSTypography.smallBold, 14, 19.6, .bold),
            (DSTypography.smallRegular, 14, 19.6, .regular),
        ]
        for (token, size, lineHeight, weight) in body {
            #expect(token.family == .sfPro)
            #expect(token.size == size)
            #expect(abs(token.lineHeight - lineHeight) < 0.001)
            #expect(abs(token.lineHeight - token.size * 1.4) < 0.001)
            #expect(token.weight == weight)
        }
    }

    @Test func handwrittenMirrorsBodySizes() {
        let pairs: [(DSTypographyToken, DSTypographyToken)] = [
            (DSTypography.Handwritten.largeBold, DSTypography.largeBold),
            (DSTypography.Handwritten.largeRegular, DSTypography.largeRegular),
            (DSTypography.Handwritten.mediumBold, DSTypography.mediumBold),
            (DSTypography.Handwritten.mediumRegular, DSTypography.mediumRegular),
            (DSTypography.Handwritten.normalBold, DSTypography.normalBold),
            (DSTypography.Handwritten.normalRegular, DSTypography.normalRegular),
            (DSTypography.Handwritten.smallBold, DSTypography.smallBold),
            (DSTypography.Handwritten.smallRegular, DSTypography.smallRegular),
        ]
        for (handwritten, sfPro) in pairs {
            #expect(handwritten.family == .architectsDaughter)
            #expect(handwritten.size == sfPro.size)
            #expect(handwritten.lineHeight == sfPro.lineHeight)
        }
    }

    @Test func lineSpacingIsNeverNegative() {
        let tokens = [
            DSTypography.heading1, DSTypography.heading6,
            DSTypography.largeRegular, DSTypography.smallRegular,
            DSTypography.Handwritten.largeRegular, DSTypography.Handwritten.smallRegular,
        ]
        for token in tokens {
            #expect(token.lineSpacing >= 0)
        }
    }

    @Test func architectsDaughterFontIsBundledAndRegistered() {
        #expect(Bundle.main.url(forResource: "ArchitectsDaughter-Regular", withExtension: "ttf") != nil)
        #expect(DSFontRegistrar.isArchitectsDaughterAvailable)
        #expect(UIFont(name: DSFontRegistrar.architectsDaughter, size: 16) != nil)
        // "Bold" uses the Regular file (only weight available).
        #expect(DSTypography.Handwritten.largeBold.uiFont.fontName == DSFontRegistrar.architectsDaughter)
    }

    @Test func iconAssetsExist() {
        for icon in DSIcon.allCases {
            #expect(UIImage(named: icon.rawValue) != nil, "\(icon.rawValue)")
        }
    }
}
