import SwiftUI

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
                .clipShape(SpineShape())
        }
        .compositingGroup()
        .shadow(color: Color(red: 0.16, green: 0.1, blue: 0.04).opacity(0.35), radius: 2, y: 2)
        .aspectRatio(ScrapbookPage.Role.spine.aspectRatio, contentMode: .fit)
        .allowsHitTesting(false)
    }
}

/// The spine's outline: corners of 4 pt in the 74 pt wide Figma spine, so a small shelf spine keeps the same look.
private struct SpineShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: 4 * rect.width / 74)
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
