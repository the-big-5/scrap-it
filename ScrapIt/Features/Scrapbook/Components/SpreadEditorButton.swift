import SwiftUI

/// Round toolbar button of the spread editor (change 025): white capsule with the hard ink shadow of
/// `CircleIconButton`, for an SF Symbol or a Figma icon image.
struct SpreadEditorButton: View {
    enum Icon {
        case system(String)
        case asset(String, template: Bool)
    }

    let icon: Icon
    var width: CGFloat = 44
    let accessibilityLabel: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            label
                .opacity(isEnabled ? 1 : 0.3)
                .frame(width: width, height: 44)
                .background(
                    ZStack {
                        Capsule().fill(ScrapTheme.charcoal).offset(y: 3)
                        Capsule().fill(Color.white)
                            .overlay(Capsule().stroke(ScrapTheme.charcoal, lineWidth: 1.5))
                    }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var label: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ScrapTheme.charcoal)
        case .asset(let name, let template):
            Image(name)
                .renderingMode(template ? .template : .original)
                .resizable()
                .frame(width: width, height: 44)
                .foregroundStyle(ScrapTheme.charcoal)
        }
    }
}
