import SwiftUI

/// Text button from the Figma "Button" component. Use `.disabled(true)` for the Disabled look.
struct DSButton: View {
    let title: LocalizedStringKey
    var variant: DSButtonVariant = .primary
    var size: DSButtonSize = .normal
    var isFullWidth = false
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        variant: DSButtonVariant = .primary,
        size: DSButtonSize = .normal,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.size = size
        self.isFullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.ds(variant, size: size, fullWidth: isFullWidth))
    }
}

#Preview("Buttons") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(DSButtonSize.allCases, id: \.self) { size in
                Text(String(describing: size).capitalized)
                    .dsTypography(DSTypography.smallBold)
                    .foregroundStyle(DSColor.Component.textSecondary)
                HStack(spacing: 12) {
                    DSButton("Start Camera Roll", variant: .primary, size: size) {}
                    DSButton("Start Camera Roll", variant: .secondary, size: size) {}
                }
                HStack(spacing: 12) {
                    DSButton("See all", variant: .tertiary, size: size) {}
                    DSButton("Start Camera Roll", size: size) {}
                        .disabled(true)
                }
            }
            Text("Full width")
                .dsTypography(DSTypography.smallBold)
                .foregroundStyle(DSColor.Component.textSecondary)
            DSButton("Start Camera Roll", size: .large, fullWidth: true) {}
            DSButton("Start Camera Roll", variant: .secondary, size: .large, fullWidth: true) {}
            DSButton("Start Camera Roll", size: .large, fullWidth: true) {}
                .disabled(true)
        }
        .padding()
    }
    .background(DSColor.Paper.normal)
}
