import SwiftUI

/// The Pencil second tray (change 022, Figma 1306:50774): tools sticking out of the tray's pocket, then the
/// color circle. Tapping the active tool opens the size and opacity panel (`PenSizePanel`).
struct PencilTray: View {
    @Bindable var controller: PencilController

    var body: some View {
        let area = TrayStyle.subTrayContentBottom - TrayStyle.stitchInset
        TrayScroll(contentBottom: TrayStyle.subTrayContentBottom, spacing: 16) {
            ForEach(PencilToolKind.allCases) { tool in
                let isActive = controller.tool == tool
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isActive {
                        controller.showsSizePanel.toggle()
                    } else {
                        controller.tool = tool
                        controller.showsSizePanel = false
                    }
                } label: {
                    // The whole tool sits in the pocket; the active one is pulled out a little.
                    PocketItem(assetName: tool.assetName, imageHeight: tool.imageHeight,
                               visibleHeight: min(tool.visibleHeight, area - 12), areaHeight: area,
                               centerOffset: tool.centerOffset, lift: isActive ? 6 : 0, isActive: isActive)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.title)
            }

            ColorWell(color: $controller.color)
                .padding(.leading, 4)
                .accessibilityLabel("Pick color")
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: controller.tool)
    }
}

/// Size and opacity panel from Figma (1144:25595): stitched red leather, five stroke sizes (the picked one on
/// cream), and an opacity slider fading to the ink color.
struct PenSizePanel: View {
    @Bindable var controller: PencilController

    private static let cream = Color(red: 0.965, green: 0.945, blue: 0.906)

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4.7) {
                ForEach(0..<PencilController.widthMultipliers.count, id: \.self) { level in
                    let isSelected = controller.widthLevel == level
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        controller.widthLevel = level
                    } label: {
                        Image("tray-pen-size-\(level + 1)")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 18.7, height: 18.7)
                            .foregroundStyle(isSelected ? TrayStyle.leather : Self.cream)
                            .frame(width: 25.5, height: 25.5)
                            .background(RoundedRectangle(cornerRadius: 4).fill(isSelected ? Self.cream : .clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Size \(level + 1)")
                }
            }
            OpacitySlider(value: $controller.opacity, color: controller.color)
                .frame(width: 146, height: 17)
        }
        .padding(8)
        .background(TrayBackground(shape: RoundedRectangle(cornerRadius: 8)))
    }
}

private struct OpacitySlider: View {
    @Binding var value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let knob: CGFloat = 14.5
            let travel = geometry.size.width - knob - 3
            let progress = (value - 0.1) / 0.9
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.965, green: 0.945, blue: 0.906), color],
                                         startPoint: .leading, endPoint: .trailing))
                Circle()
                    .fill(color.opacity(value))
                    .background(Circle().fill(Color(red: 0.965, green: 0.945, blue: 0.906)))
                    .overlay(Circle().stroke(TrayStyle.leather, lineWidth: 1.5))
                    .frame(width: knob, height: knob)
                    .offset(x: 1.5 + travel * progress)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let p = min(max((drag.location.x - knob / 2) / travel, 0), 1)
                        value = 0.1 + Double(p) * 0.9
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Opacity")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            value = min(max(value + (direction == .increment ? 0.1 : -0.1), 0.1), 1)
        }
    }
}

/// White circle with a rainbow ring as in Figma; tapping opens the system color picker.
private struct ColorWell: View {
    @Binding var color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 52, height: 52)
            Circle()
                .strokeBorder(AngularGradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                                              center: .center), lineWidth: 4)
                .frame(width: 38, height: 38)
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)
            // The system color picker can't be restyled, so it sits transparent on top.
            ColorPicker("Color", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(2)
                .opacity(0.02)
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }
}
