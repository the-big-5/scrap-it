import SwiftUI

/// Icons exported from Figma as template SVGs (Assets.xcassets/DesignSystem); tint with `foregroundStyle`.
enum DSIcon: String, CaseIterable, Sendable {
    case plus = "DSIconPlus"
    case play = "DSIconPlay"
    case check = "DSIconCheck"
    case close = "DSIconClose"
    case eyeSlash = "DSIconEyeSlash"
    case search = "DSIconSearch"

    func image(size: CGFloat) -> some View {
        Image(rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
