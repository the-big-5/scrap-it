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
            case .none:
                break
            }
        }
    }
}
