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

/// The spine (change 026, Figma 1515:27778): the cover color with the Figma cloth stripes and the two bands near
/// the ends. Sized from the 74 × 462 Figma spine.
struct BookSpineArt: View {
    let colorHex: String

    /// x, width, white (else black), opacity of each stripe, from the Figma vectors (all at 45%).
    private static let stripes: [(x: CGFloat, width: CGFloat, isWhite: Bool, opacity: Double)] = [
        (67.1, 2, true, 0.06), (35.5, 3, false, 0.06), (7.5, 1, true, 0.04), (30, 2, false, 0.07),
        (11.8, 2, false, 0.07), (44.8, 3, false, 0.09), (77.6, 3, true, 0.05), (67.7, 2, false, 0.06),
        (43.4, 1, true, 0.05), (71.4, 1, false, 0.09), (55.1, 1, true, 0.05), (69, 2, false, 0.06),
        (11.4, 3, true, 0.05), (60.1, 2, true, 0.05), (4.1, 1, false, 0.07), (25.9, 3, false, 0.08),
        (77.2, 2, true, 0.04), (52.4, 2, false, 0.06), (40.8, 2, false, 0.06), (40.3, 2, false, 0.08),
        (64.4, 2, true, 0.04), (61.2, 2, false, 0.07),
    ]

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 74
            let sy = size.height / 462
            let shape = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4 * sx)
            context.clip(to: shape)
            context.fill(shape, with: .color(Color(coverHex: colorHex)))
            for stripe in Self.stripes {
                let rect = CGRect(x: (stripe.x - 4) * sx, y: 0, width: stripe.width * sx, height: size.height)
                context.fill(Path(rect), with: .color((stripe.isWhite ? Color.white : .black).opacity(stripe.opacity * 0.45)))
            }
            // Bands near both ends: dark 2 pt lines at 18 / 444, light 1.5 pt lines at 22 / 448.
            for y: CGFloat in [18, 444] {
                context.fill(Path(CGRect(x: 0, y: (y - 1) * sy, width: size.width, height: 2 * sy)),
                             with: .color(Color(red: 18 / 255, green: 26 / 255, blue: 48 / 255).opacity(0.35)))
            }
            for y: CGFloat in [22, 448] {
                context.fill(Path(CGRect(x: 0, y: (y - 0.75) * sy, width: size.width, height: 1.5 * sy)),
                             with: .color(.white.opacity(0.08)))
            }
        }
        .overlay {
            Image("BookCoverTexture")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.55)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .compositingGroup()
        .shadow(color: Color(red: 0.16, green: 0.1, blue: 0.04).opacity(0.35), radius: 2, y: 2)
        .aspectRatio(ScrapbookPage.Role.spine.aspectRatio, contentMode: .fit)
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

/// UIKit's color picker (grid, spectrum, sliders), reporting each change.
private struct SystemColorPicker: UIViewControllerRepresentable {
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

extension Color {
    /// "#RRGGBB" → color (white when it can't be read).
    init(coverHex hex: String) {
        let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let rgb = UInt64(clean, radix: 16) ?? 0xFFFFFF
        self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }

    /// "#RRGGBB" of this color.
    var coverHex: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}
