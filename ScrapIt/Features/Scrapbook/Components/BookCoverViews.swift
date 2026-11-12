import SwiftUI
import UIKit

/// The front cover's material (change 026, Figma 1444:23837 / 1515:29529), drawn so its color can change: the
/// chosen color, a soft light mottle, the paper grain from the Figma cover image (`BookCoverTexture`), the spine
/// hinge along the left edge, an inner shadow and a drop shadow. Sized from the 340 × 468 Figma cover.
struct BookCoverArt: View {
    let colorHex: String

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 340
            let shape = UnevenRoundedRectangle(topLeadingRadius: 3 * scale, bottomLeadingRadius: 3 * scale,
                                               bottomTrailingRadius: 9 * scale, topTrailingRadius: 9 * scale)
            ZStack(alignment: .topLeading) {
                Color(coverHex: colorHex)
                // Light mottle (ellipse 280 × 220 at 74, 22, white 14%, blur 20).
                Ellipse()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 280 * scale, height: 220 * scale)
                    .position(x: 74 * scale, y: 22 * scale)
                    .blur(radius: 20 * scale)
                // Paper grain: neutral grey, so any color keeps the texture.
                Image("BookCoverTexture")
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(0.55)
                // Spine hinge (28 pt).
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.38), location: 0),
                    .init(color: .black.opacity(0.08), location: 0.62),
                    .init(color: .white.opacity(0.1), location: 0.78),
                    .init(color: .black.opacity(0.18), location: 0.92),
                    .init(color: .black.opacity(0.05), location: 1),
                ], startPoint: .leading, endPoint: .trailing)
                .frame(width: 28 * scale)
                .frame(maxHeight: .infinity)
                // Inner shadow (blur 14, black 30%).
                shape.stroke(Color.black.opacity(0.3), lineWidth: 14 * scale).blur(radius: 14 * scale)
            }
            .clipShape(shape)
            .compositingGroup()
            .shadow(color: Color(red: 0.16, green: 0.1, blue: 0.04).opacity(0.35), radius: 2 * scale, y: 2 * scale)
        }
        .aspectRatio(ScrapbookPage.Role.front.aspectRatio, contentMode: .fit)
        .allowsHitTesting(false)
    }
}

/// The cutting mat of the cover screens (change 026, Figma 1444:23794): green, 20 pt minor and 100 pt major grid,
/// ticked edges top and bottom and a light edge line. Drawn in the 1257 × 874 design space, centered.
struct CoverCuttingMat: View {
    private static let cream = Color(red: 246 / 255, green: 241 / 255, blue: 231 / 255)

    var body: some View {
        Canvas { context, size in
            let scale = size.height / 874
            let originX = size.width / 2 - 628.5 * scale
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 45 / 255, green: 119 / 255, blue: 88 / 255), location: 0),
                    .init(color: Color(red: 44 / 255, green: 118 / 255, blue: 87 / 255), location: 0.55),
                    .init(color: Color(red: 48 / 255, green: 121 / 255, blue: 90 / 255), location: 1),
                ]),
                center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: 0, endRadius: 938 * scale
            ))
            // Grid from (14, 14) of the mat: minor every 20, major every 100.
            var minor = Path()
            var major = Path()
            var x: CGFloat = 0
            while originX + (14 + x) * scale < size.width {
                let px = originX + (14 + x) * scale
                var line = Path()
                line.move(to: CGPoint(x: px, y: 14 * scale))
                line.addLine(to: CGPoint(x: px, y: size.height - 14 * scale))
                if Int(x) % 100 == 0 { major.addPath(line) } else { minor.addPath(line) }
                x += 20
            }
            var y: CGFloat = 0
            while (14 + y) * scale < size.height - 14 * scale {
                let py = (14 + y) * scale
                var line = Path()
                line.move(to: CGPoint(x: 0, y: py))
                line.addLine(to: CGPoint(x: size.width, y: py))
                if Int(y) % 100 == 0 { major.addPath(line) } else { minor.addPath(line) }
                y += 20
            }
            context.stroke(minor, with: .color(Self.cream.opacity(0.15)), lineWidth: max(scale, 0.5))
            context.stroke(major, with: .color(Self.cream.opacity(0.34)), lineWidth: max(scale, 0.5))
            // Ticked edges top and bottom.
            let edge = Color(red: 44 / 255, green: 118 / 255, blue: 87 / 255)
            for top: CGFloat in [0, size.height - 14 * scale] {
                context.fill(Path(CGRect(x: 0, y: top, width: size.width, height: 14 * scale)), with: .color(edge))
                var ticks = Path()
                var tx = originX
                var index = 0
                while tx < size.width {
                    let length: CGFloat = index % 10 == 0 ? 8 : (index % 5 == 0 ? 6 : 4)
                    ticks.move(to: CGPoint(x: tx, y: top + 3 * scale))
                    ticks.addLine(to: CGPoint(x: tx, y: top + (3 + length) * scale))
                    tx += 10 * scale
                    index += 1
                }
                context.stroke(ticks, with: .color(Self.cream.opacity(0.75)), lineWidth: max(scale, 0.5))
            }
            context.stroke(Path(CGRect(x: originX + 15 * scale, y: 15 * scale,
                                       width: 1227 * scale, height: size.height - 30 * scale)),
                           with: .color(Color(red: 243 / 255, green: 227 / 255, blue: 189 / 255).opacity(0.85)),
                           lineWidth: 2 * scale)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// The round color picker above the tray (change 026, Figma 1444:24253): black ring, rainbow ring, the cover color in
/// the middle. Tapping opens the system color picker in a sheet.
struct CoverColorButton: View {
    let colorHex: String
    let onChange: (String) -> Void
    @State private var isPickerPresented = false

    var body: some View {
        Button {
            isPickerPresented = true
        } label: {
            ZStack {
                Circle().fill(Color.black).frame(width: 54, height: 54)
                Circle()
                    .fill(AngularGradient(stops: [
                        .init(color: Color(red: 231 / 255, green: 224 / 255, blue: 64 / 255), location: 0),
                        .init(color: Color(red: 238 / 255, green: 170 / 255, blue: 60 / 255), location: 0.124),
                        .init(color: Color(red: 232 / 255, green: 64 / 255, blue: 59 / 255), location: 0.249),
                        .init(color: Color(red: 179 / 255, green: 62 / 255, blue: 213 / 255), location: 0.366),
                        .init(color: Color(red: 105 / 255, green: 74 / 255, blue: 232 / 255), location: 0.506),
                        .init(color: Color(red: 60 / 255, green: 202 / 255, blue: 231 / 255), location: 0.643),
                        .init(color: Color(red: 60 / 255, green: 232 / 255, blue: 133 / 255), location: 0.749),
                        .init(color: Color(red: 137 / 255, green: 231 / 255, blue: 67 / 255), location: 0.869),
                        .init(color: Color(red: 231 / 255, green: 224 / 255, blue: 64 / 255), location: 1),
                    ], center: .center, angle: .degrees(90)))
                    .frame(width: 36, height: 36)
                Circle()
                    .fill(Color(coverHex: colorHex))
                    .frame(width: 26, height: 26)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cover color")
        .sheet(isPresented: $isPickerPresented) {
            SystemColorPicker(color: Color(coverHex: colorHex)) { onChange($0.coverHex) }
                .presentationDetents([.medium, .large])
        }
    }
}

/// UIKit's color picker (grid, spectrum, sliders), reporting each change. Also the Pencil color circle (change 114).
struct SystemColorPicker: UIViewControllerRepresentable {
    let color: Color
    let onChange: (Color) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = UIColor(color)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIColorPickerViewController, context: Context) {
        context.coordinator.onChange = onChange
    }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        var onChange: (Color) -> Void

        init(onChange: @escaping (Color) -> Void) {
            self.onChange = onChange
        }

        func colorPickerViewController(_ picker: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
            onChange(Color(uiColor: color))
        }
    }
}
