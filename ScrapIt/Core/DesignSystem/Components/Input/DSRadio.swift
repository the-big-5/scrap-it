import SwiftUI

/// Figma "Radio": 22pt ring; selected adds a 12pt leather dot.
struct DSRadio: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    init(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            DSControlRow {
                ZStack {
                    Circle().fill(DSColor.Component.surface)
                    Circle().strokeBorder(
                        isSelected ? DSColor.Camera.leather : DSColor.Component.disabledText,
                        lineWidth: 1.5
                    )
                    if isSelected {
                        Circle()
                            .fill(DSColor.Camera.leather)
                            .frame(width: 12, height: 12)
                    }
                }
                .frame(width: 22, height: 22)
            } label: {
                Text(title)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A vertical group of `DSRadio` rows bound to one selection.
struct DSRadioGroup<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: LocalizedStringKey)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                DSRadio(option.title, isSelected: selection == option.value) {
                    selection = option.value
                }
            }
        }
    }
}

private struct DSRadioPreview: View {
    @State private var selection = 1

    var body: some View {
        DSRadioGroup(
            selection: $selection,
            options: [(0, "When the roll ends"), (1, "Next morning, 08:00")]
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DSColor.Paper.normal)
    }
}

#Preview("Radio") {
    DSRadioPreview()
}
