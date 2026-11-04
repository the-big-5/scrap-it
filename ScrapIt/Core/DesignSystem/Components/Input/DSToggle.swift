import SwiftUI
import UIKit

/// Figma "Toggle - Switch" (647:4387): 64×28 track, 39×24 knob.
/// On: cognac track. Off: labels/tertiary track.
/// The on/off glyphs ("AX Label") show when Settings › Accessibility › On/Off Labels is on.
struct DSToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                configuration.label
                    .font(DSTypography.normalRegular.font)
                    .foregroundStyle(DSColor.Brand.primary)
                Spacer(minLength: 0)
                DSToggleTrack(isOn: configuration.isOn)
            }
            .frame(minHeight: dsMinimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

private struct DSToggleTrack: View {
    let isOn: Bool

    private var showsOnOffLabels: Bool { UIAccessibility.isOnOffSwitchLabelsEnabled }

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? DSColor.Camera.cognac : DSColor.Component.labelTertiary)
            if showsOnOffLabels {
                onOffLabel
                    .frame(width: 21, height: 10)
                    .frame(maxWidth: .infinity, alignment: isOn ? .leading : .trailing)
                    .padding(.horizontal, 2)
            }
            Capsule()
                .fill(DSColor.Component.white)
                .frame(width: 39, height: 24)
                .padding(2)
        }
        .frame(width: 64, height: 28)
    }

    @ViewBuilder
    private var onOffLabel: some View {
        if isOn {
            Rectangle()
                .fill(DSColor.Component.white)
                .frame(width: 1, height: 10)
        } else {
            Circle()
                .stroke(DSColor.Component.toggleOffLabel, lineWidth: 1)
                .frame(width: 9, height: 9)
        }
    }
}

extension ToggleStyle where Self == DSToggleStyle {
    static var ds: DSToggleStyle { DSToggleStyle() }
}

struct DSToggle: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.ds)
    }
}

private struct DSTogglePreview: View {
    @State private var on = true
    @State private var off = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSToggle("Save photos to my gallery", isOn: $on)
            DSToggle("Save photos to my gallery", isOn: $off)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DSColor.Paper.normal)
    }
}

#Preview("Toggle") {
    DSTogglePreview()
}
