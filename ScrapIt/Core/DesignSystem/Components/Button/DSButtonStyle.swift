import SwiftUI

/// Figma "Button" component (722:887). Disabled is not a variant here: any variant
/// shows the Figma "Disabled" look when the button is disabled (`.disabled(true)`).
enum DSButtonVariant: CaseIterable, Sendable {
    case primary
    case secondary
    case tertiary
}

enum DSButtonSize: CaseIterable, Sendable {
    case small
    case normal
    case large

    /// Variables `height/small|normal|large`.
    var height: CGFloat {
        switch self {
        case .small: 32
        case .normal: 44
        case .large: 52
        }
    }

    fileprivate var filledHorizontalPadding: CGFloat {
        switch self {
        case .small: 10
        case .normal, .large: 14
        }
    }

    fileprivate var tertiaryHorizontalPadding: CGFloat {
        switch self {
        case .small: 6
        case .normal: 8
        case .large: 10
        }
    }

    fileprivate var tertiaryCornerRadius: CGFloat {
        switch self {
        case .small: 10
        case .normal: 12
        case .large: 14
        }
    }

    /// Typography/Body/Small|Normal|Medium.
    fileprivate var bodySize: DSTypography.BodySize {
        switch self {
        case .small: .small
        case .normal: .normal
        case .large: .medium
        }
    }
}

/// Pressed state is not designed in Figma [Open]; it uses 0.7 opacity.
let dsPressedOpacity: Double = 0.7

/// Minimum tap target for every interactive design system component.
let dsMinimumTapTarget: CGFloat = 44

struct DSButtonStyle: ButtonStyle {
    var variant: DSButtonVariant = .primary
    var size: DSButtonSize = .normal
    var isFullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        DSButtonBody(
            configuration: configuration,
            variant: variant,
            size: size,
            isFullWidth: isFullWidth
        )
    }
}

private struct DSButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let variant: DSButtonVariant
    let size: DSButtonSize
    let isFullWidth: Bool

    @Environment(\.isEnabled) private var isEnabled

    private var isTertiary: Bool { variant == .tertiary && isEnabled }

    private var typography: DSTypographyToken {
        // Tertiary labels are Semibold, the others Regular (as in the Figma component).
        DSTypography.body(.sfPro, isTertiary ? .semibold : .regular, size.bodySize)
    }

    private var foreground: DSColorToken {
        guard isEnabled else { return DSColor.Component.labelTertiary }
        switch variant {
        case .primary: return DSColor.Component.white
        case .secondary: return DSColor.Brand.tertiary
        case .tertiary: return DSColor.Camera.leather
        }
    }

    private var background: DSColorToken? {
        guard isEnabled else { return DSColor.Component.fillTertiary }
        switch variant {
        case .primary: return DSColor.Brand.primary
        case .secondary: return DSColor.Component.fillTertiary
        case .tertiary: return nil
        }
    }

    private var shape: AnyShape {
        isTertiary
            ? AnyShape(RoundedRectangle(cornerRadius: size.tertiaryCornerRadius, style: .continuous))
            : AnyShape(Capsule())
    }

    var body: some View {
        configuration.label
            .dsTypography(typography)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, isTertiary ? size.tertiaryHorizontalPadding : size.filledHorizontalPadding)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .background {
                if let background {
                    shape.fill(background)
                }
            }
            .contentShape(shape)
            .opacity(configuration.isPressed ? dsPressedOpacity : 1)
            // Keeps the tap target at least 44pt without changing the visible size.
            .frame(minHeight: dsMinimumTapTarget)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    static func ds(
        _ variant: DSButtonVariant = .primary,
        size: DSButtonSize = .normal,
        fullWidth: Bool = false
    ) -> DSButtonStyle {
        DSButtonStyle(variant: variant, size: size, isFullWidth: fullWidth)
    }
}
