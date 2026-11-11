import SwiftUI

/// Page background drawn in code, scaled to the page width so it looks the same on every screen (POC).
struct PageBackgroundView: View {
    let background: PageBackground

    var body: some View {
        Canvas { context, size in
            let rgb = background.baseRGB
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: rgb.red, green: rgb.green, blue: rgb.blue)))

            let spacing = size.width / 18
            let lineWidth = max(0.5, size.width / 600)
            let ink = Color(red: 0.45, green: 0.62, blue: 0.82).opacity(0.45)

            switch background.pattern {
            case .lined:
                var lines = Path()
                var y = spacing * 2
                while y < size.height {
                    lines.move(to: CGPoint(x: 0, y: y))
                    lines.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(lines, with: .color(ink), lineWidth: lineWidth)
                var margin = Path()
                margin.move(to: CGPoint(x: spacing * 2, y: 0))
                margin.addLine(to: CGPoint(x: spacing * 2, y: size.height))
                context.stroke(margin, with: .color(.red.opacity(0.35)), lineWidth: lineWidth)
            case .grid:
                var lines = Path()
                var x = spacing
                while x < size.width {
                    lines.move(to: CGPoint(x: x, y: 0))
                    lines.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y = spacing
                while y < size.height {
                    lines.move(to: CGPoint(x: 0, y: y))
                    lines.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(lines, with: .color(ink.opacity(0.7)), lineWidth: lineWidth)
            case .dotted:
                let radius = max(0.8, size.width / 400)
                var dots = Path()
                var y = spacing
                while y < size.height {
                    var x = spacing
                    while x < size.width {
                        dots.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                        x += spacing
                    }
                    y += spacing
                }
                context.fill(dots, with: .color(ink))
            case .paperDots:
                // Figma page (1274:33452): r 1 pt dots every 22 pt on a 201 pt page, #4F4121 at 50% × 20%.
                let step = size.width * 22 / 201
                let radius = size.width / 201
                var dots = Path()
                var y = radius
                while y < size.height {
                    var x = radius
                    while x < size.width {
                        dots.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                        x += step
                    }
                    y += step
                }
                context.fill(dots, with: .color(Color(red: 79 / 255, green: 65 / 255, blue: 33 / 255).opacity(0.1)))
            case .none:
                break
            }
        }
    }
}

extension View {
    /// The Figma page edge (change 025, 1274:33452): an inner shadow (blur 14.72, black 19% on a 201 pt page) that
    /// also marks where the two pages of a spread meet.
    func scrapbookPageEdgeShadow() -> some View {
        overlay {
            GeometryReader { geometry in
                let blur = geometry.size.width * 7.36 / 201
                Rectangle()
                    .stroke(Color.black.opacity(0.19), lineWidth: blur * 2)
                    .blur(radius: blur)
            }
            .clipped()
            .allowsHitTesting(false)
        }
    }
}
