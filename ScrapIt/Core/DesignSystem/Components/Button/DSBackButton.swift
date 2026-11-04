import SwiftUI

/// Figma back circle button ("Button - Content Area" 728:5935 / 5937 / 5939).
enum DSBackButtonSize: CaseIterable, Sendable {
    case small
    case normal
    case large

    var diameter: CGFloat {
        switch self {
        case .small: 28
        case .normal: 34
        case .large: 50
        }
    }
}

struct DSBackButton: View {
    var size: DSBackButtonSize = .normal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 15, weight: .regular))
        }
        .buttonStyle(DSBackButtonStyle(size: size))
        .accessibilityLabel("Back")
    }
}

private struct DSBackButtonStyle: ButtonStyle {
    let size: DSBackButtonSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DSColor.Camera.cognac)
            .frame(width: size.diameter, height: size.diameter)
            .background(Circle().fill(DSColor.Component.fillTertiary))
            .opacity(configuration.isPressed ? dsPressedOpacity : 1)
            // Keeps the tap target at least 44pt without changing the visible size.
            .frame(minWidth: dsMinimumTapTarget, minHeight: dsMinimumTapTarget)
            .contentShape(Rectangle())
    }
}

#Preview("Back buttons") {
    HStack(spacing: 12) {
        ForEach(DSBackButtonSize.allCases, id: \.self) { size in
            DSBackButton(size: size) {}
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DSColor.Paper.normal)
}
