import SwiftUI

/// Figma "Icon · 44" buttons: a 44pt circle with a 20pt icon.
struct DSIconButtonStyle: ButtonStyle {
    var variant: DSButtonVariant = .primary

    func makeBody(configuration: Configuration) -> some View {
        DSIconButtonBody(configuration: configuration, variant: variant)
    }
}

private struct DSIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let variant: DSButtonVariant

    @Environment(\.isEnabled) private var isEnabled

    private var foreground: DSColorToken {
        guard isEnabled else { return DSColor.Component.disabledText }
        switch variant {
        case .primary: return DSColor.Paper.normal
        case .secondary: return DSColor.Brand.primary
        case .tertiary: return DSColor.Camera.cognac
        }
    }

    private var background: DSColorToken? {
        guard isEnabled else { return DSColor.Component.disabledBackground }
        switch variant {
        case .primary: return DSColor.Brand.primary
        case .secondary: return nil
        case .tertiary: return DSColor.Kraft.normal
        }
    }

    var body: some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(width: 44, height: 44)
            .background {
                if let background {
                    Circle().fill(background)
                }
            }
            .overlay {
                if isEnabled && variant == .secondary {
                    Circle().strokeBorder(DSColor.Brand.primary, lineWidth: 1.5)
                }
            }
            .contentShape(Circle())
            .opacity(configuration.isPressed ? dsPressedOpacity : 1)
    }
}

struct DSIconButton: View {
    let icon: DSIcon
    let accessibilityLabel: LocalizedStringKey
    var variant: DSButtonVariant = .primary
    let action: () -> Void

    init(
        _ icon: DSIcon,
        accessibilityLabel: LocalizedStringKey,
        variant: DSButtonVariant = .primary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.variant = variant
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            icon.image(size: 20)
        }
        .buttonStyle(DSIconButtonStyle(variant: variant))
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Icon buttons") {
    VStack(alignment: .leading, spacing: 16) {
        ForEach(DSButtonVariant.allCases, id: \.self) { variant in
            HStack(spacing: 12) {
                DSIconButton(.plus, accessibilityLabel: "Add", variant: variant) {}
                DSIconButton(.play, accessibilityLabel: "Play", variant: variant) {}
            }
        }
        HStack(spacing: 12) {
            DSIconButton(.plus, accessibilityLabel: "Add") {}
            DSIconButton(.play, accessibilityLabel: "Play") {}
        }
        .disabled(true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DSColor.Paper.normal)
}
