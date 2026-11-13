import SwiftUI

/// Reusable empty-state layout shared across workbench collection screens (Figma 1537:25830, 1537:25997).
struct DeskEmptyStateView<Illustration: View>: View {
    let title: String
    let message: String
    let actionTitle: String
    let onAction: () -> Void
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            illustration()

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Text(message)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 311)
                .padding(.top, 14)

            DSButton(LocalizedStringKey(actionTitle), variant: .primary, size: .large, fullWidth: true, action: onAction)
                .frame(width: 217)
                .padding(.top, 26)

            Spacer(minLength: 48)
        }
        .padding(.horizontal, 24)
    }
}
