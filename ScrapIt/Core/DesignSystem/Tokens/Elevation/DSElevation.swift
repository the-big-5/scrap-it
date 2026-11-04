import SwiftUI

/// Elevation tokens. Figma has no elevation yet [Open]; the one level is copied from
/// the existing `OffsetPillButtonStyle`: a solid shape offset below the content.
enum DSElevation: Hashable, Sendable {
    case level1

    /// Offset of the solid shadow shape at rest.
    var offset: CGFloat {
        switch self {
        case .level1: 5
        }
    }

    /// Offset while pressed; the content also moves down by this amount.
    var pressedOffset: CGFloat {
        switch self {
        case .level1: 2
        }
    }

    var color: DSColorToken {
        switch self {
        case .level1: DSColor.Brand.primary
        }
    }
}

private struct DSElevationModifier<S: Shape>: ViewModifier {
    let level: DSElevation
    let shape: S
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: isPressed ? level.pressedOffset : 0)
            .background(
                shape
                    .fill(level.color)
                    .offset(y: isPressed ? level.pressedOffset : level.offset)
            )
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}

extension View {
    /// Adds a solid offset shadow in `shape` behind the view.
    func dsElevation<S: Shape>(_ level: DSElevation, in shape: S, isPressed: Bool = false) -> some View {
        modifier(DSElevationModifier(level: level, shape: shape, isPressed: isPressed))
    }
}

#Preview("Elevation") {
    VStack(spacing: 32) {
        Text("Level 1")
            .dsTypography(DSTypography.mediumBold)
            .foregroundStyle(DSColor.Brand.primary)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(Capsule().fill(DSColor.Component.white))
            .overlay(Capsule().stroke(DSColor.Brand.primary, lineWidth: 1.5))
            .dsElevation(.level1, in: Capsule())
        Text("Level 1, pressed")
            .dsTypography(DSTypography.mediumBold)
            .foregroundStyle(DSColor.Brand.primary)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(Capsule().fill(DSColor.Component.white))
            .overlay(Capsule().stroke(DSColor.Brand.primary, lineWidth: 1.5))
            .dsElevation(.level1, in: Capsule(), isPressed: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DSColor.Paper.normal)
}
