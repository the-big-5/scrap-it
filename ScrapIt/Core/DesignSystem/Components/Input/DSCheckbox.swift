import SwiftUI

/// Figma "Checkbox": 22pt box, 6pt corners; checked is cognac with a 14pt check.
struct DSCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            DSControlRow {
                let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
                ZStack {
                    shape.fill(configuration.isOn ? DSColor.Camera.cognac : DSColor.Component.surface)
                    shape.strokeBorder(
                        configuration.isOn ? DSColor.Camera.cognac : DSColor.Component.disabledText,
                        lineWidth: 1.5
                    )
                    if configuration.isOn {
                        DSIcon.check.image(size: 14)
                            .foregroundStyle(DSColor.Paper.normal)
                    }
                }
                .frame(width: 22, height: 22)
            } label: {
                configuration.label
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "Checked" : "Unchecked")
    }
}

extension ToggleStyle where Self == DSCheckboxStyle {
    static var dsCheckbox: DSCheckboxStyle { DSCheckboxStyle() }
}

struct DSCheckbox: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.dsCheckbox)
    }
}

private struct DSCheckboxPreview: View {
    @State private var checked = true
    @State private var unchecked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSCheckbox("Save photos to my gallery", isOn: $checked)
            DSCheckbox("Save photos to my gallery", isOn: $unchecked)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DSColor.Paper.normal)
    }
}

#Preview("Checkbox") {
    DSCheckboxPreview()
}
