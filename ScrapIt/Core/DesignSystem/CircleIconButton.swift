import SwiftUI

/// Round 44pt toolbar button with a hard offset shadow (same look as `BackCircleButton`),
/// for any SF Symbol (Figma "Toolbar - Top" buttons: close, invite, more).
struct CircleIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIconLabel(systemName: systemName)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// The visual of `CircleIconButton`, also used as a `Menu` label.
struct CircleIconLabel: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(ScrapTheme.charcoal)
            .frame(width: 44, height: 44)
            .background(
                ZStack {
                    Circle()
                        .fill(ScrapTheme.charcoal)
                        .offset(y: 3)
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(ScrapTheme.charcoal, lineWidth: 1.5))
                }
            )
    }
}
