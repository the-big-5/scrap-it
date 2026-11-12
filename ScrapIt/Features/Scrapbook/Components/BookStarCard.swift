import SwiftUI

/// The paper card held by washi tape with the star character (change 025 / 026, Figma 1533:25816, 1563:33117,
/// 1563:33675, 1563:33475) over a dimmed screen.
struct BookStarCard: View {
    struct Action {
        enum Style { case primary, secondary, plain }
        let title: String
        let style: Style
        let action: () -> Void
    }

    var starImage = "BookConfirmStar"
    let title: String
    let message: String
    /// One or two buttons; `stacked` puts them under each other (Ready to close).
    let actions: [Action]
    var stacked = false
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss?() }

            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Image(starImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 90)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(DSColor.Component.textSecondary.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if stacked {
                    VStack(spacing: 12) { buttons }
                } else {
                    HStack(spacing: 16) { buttons }
                }
            }
            .padding(22)
            .frame(width: 337)
            .background(DSColor.Paper.normal.color, in: RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .overlay(alignment: .top) {
                Image("BookConfirmWashi")
                    .resizable()
                    .frame(width: 98, height: 35)
                    .offset(y: -14)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .contain)
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private var buttons: some View {
        ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
            // Size and capsule inside the label, so the whole capsule takes the tap, not only the title (change 114).
            Button(action: action.action) {
                Text(action.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(action.style == .primary ? DSColor.Kraft.light.color : DSColor.Brand.primary.color)
                    .frame(maxWidth: action.style == .plain && !stacked ? 108 : .infinity, minHeight: 52)
                    .background(background(for: action.style), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func background(for style: Action.Style) -> Color {
        switch style {
        case .primary: DSColor.Brand.primary.color
        case .secondary: DSColor.Brand.secondary.color
        case .plain: DSColor.Kraft.light.color
        }
    }
}
