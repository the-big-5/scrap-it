import SwiftUI

/// A piece of washi tape lying flat (change 022, camera POC): length = view width, tape width = view height.
/// Both ends are jagged as if torn by hand; the shape is the same for the same `tearSeed`.
struct WashiTapeView: View {
    let style: WashiStyle
    let tearSeed: Int
    /// `false` while the tape is still being pulled from the roll: the far end is straight (not torn yet).
    var isTornAtEnd = true

    var body: some View {
        Canvas { context, size in
            let shape = WashiTapeShape(seed: tearSeed, isTornAtEnd: isTornAtEnd).path(in: CGRect(origin: .zero, size: size))
            context.clip(to: shape)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(style.palette.base))
            WashiPattern.draw(style, in: &context, size: size)
            // A thin sheen along the top edge, like paper tape.
            context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.08)),
                         with: .color(.white.opacity(0.18)))
        }
        .opacity(WashiCatalog.opacity)
    }
}

/// Colors of each washi pattern (Figma Washi tray).
struct WashiPalette {
    let base: Color
    let accent: Color
    let accent2: Color
}

extension WashiStyle {
    var palette: WashiPalette {
        switch motif {
        case .triangles:
            WashiPalette(base: Color(red: 0.96, green: 0.80, blue: 0.58),
                         accent: Color(red: 0.91, green: 0.66, blue: 0.40),
                         accent2: Color(red: 0.99, green: 0.90, blue: 0.75))
        case .crosses:
            WashiPalette(base: Color(red: 0.13, green: 0.42, blue: 0.38),
                         accent: Color(red: 0.80, green: 0.91, blue: 0.85),
                         accent2: Color(red: 0.36, green: 0.62, blue: 0.56))
        case .waves:
            WashiPalette(base: Color(red: 0.16, green: 0.67, blue: 0.75),
                         accent: Color(red: 0.93, green: 0.98, blue: 0.97),
                         accent2: Color(red: 0.10, green: 0.53, blue: 0.62))
        case .flowers:
            WashiPalette(base: Color(red: 0.79, green: 0.36, blue: 0.47),
                         accent: Color(red: 0.98, green: 0.80, blue: 0.85),
                         accent2: Color(red: 0.88, green: 0.55, blue: 0.64))
        }
    }
}

struct WashiTapeShape: Shape {
    let seed: Int
    var isTornAtEnd = true

    func path(in rect: CGRect) -> Path {
        var generator = SeededGenerator(seed: UInt64(bitPattern: Int64(seed)))
        let depth = rect.height * 0.09
        let teeth = 7

        func edge(atX x: CGFloat, inward: CGFloat) -> [CGPoint] {
            (0...teeth).map { index in
                let y = rect.minY + rect.height * CGFloat(index) / CGFloat(teeth)
                let jitter = CGFloat.random(in: 0...1, using: &generator)
                let offset = (index % 2 == 0 ? jitter * 0.4 : 0.6 + jitter * 0.4) * depth
                return CGPoint(x: x + inward * offset, y: y)
            }
        }

        let left = edge(atX: rect.minX, inward: 1)
        let right = isTornAtEnd ? edge(atX: rect.maxX, inward: -1) : [CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)]

        // One subpath: top to bottom on the right end, then bottom to top on the left end
        // (`addLines` starts a new subpath, so all points are joined first; brief K4).
        var path = Path()
        path.addLines(right + left.reversed())
        path.closeSubpath()
        return path
    }
}

enum WashiPattern {
    static func draw(_ style: WashiStyle, in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let unit = max(size.height / 4, 2)
        switch style.motif {
        case .triangles:
            var x: CGFloat = 0
            var flip = false
            while x < size.width + unit * 2 {
                var path = Path()
                if flip {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + unit * 2, y: 0))
                    path.addLine(to: CGPoint(x: x + unit, y: size.height / 2))
                } else {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + unit * 2, y: size.height))
                    path.addLine(to: CGPoint(x: x + unit, y: size.height / 2))
                }
                path.closeSubpath()
                context.fill(path, with: .color(flip ? style.palette.accent : style.palette.accent2))
                var mid = Path()
                mid.move(to: CGPoint(x: x + unit, y: size.height / 2))
                mid.addLine(to: CGPoint(x: x + unit * 2, y: flip ? size.height : 0))
                mid.addLine(to: CGPoint(x: x + unit * 3, y: size.height / 2))
                mid.closeSubpath()
                context.fill(mid, with: .color(style.palette.accent.opacity(0.55)))
                x += unit * 2
                flip.toggle()
            }
        case .crosses:
            let step = unit * 0.9
            let arm = step * 0.18
            var row = 0
            var y = step / 2
            while y < size.height {
                var x = row % 2 == 0 ? step / 2 : step
                while x < size.width {
                    var cross = Path()
                    cross.move(to: CGPoint(x: x - arm, y: y - arm))
                    cross.addLine(to: CGPoint(x: x + arm, y: y + arm))
                    cross.move(to: CGPoint(x: x + arm, y: y - arm))
                    cross.addLine(to: CGPoint(x: x - arm, y: y + arm))
                    context.stroke(cross, with: .color(style.palette.accent), lineWidth: max(arm * 0.6, 0.6))
                    x += step
                }
                y += step
                row += 1
            }
        case .waves:
            let amplitude = unit * 0.28
            let wavelength = unit * 1.1
            var y = unit * 0.5
            while y < size.height {
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: y))
                var x: CGFloat = 0
                while x < size.width {
                    wave.addQuadCurve(to: CGPoint(x: x + wavelength / 2, y: y),
                                      control: CGPoint(x: x + wavelength / 4, y: y - amplitude * 2))
                    wave.addQuadCurve(to: CGPoint(x: x + wavelength, y: y),
                                      control: CGPoint(x: x + wavelength * 3 / 4, y: y + amplitude * 2))
                    x += wavelength
                }
                context.stroke(wave, with: .color(style.palette.accent), lineWidth: max(unit * 0.16, 0.8))
                y += unit
            }
        case .flowers:
            let step = unit * 1.3
            var row = 0
            var y = step * 0.45
            while y < size.height {
                var x = row % 2 == 0 ? step * 0.4 : step * 0.95
                while x < size.width {
                    let radius = unit * (row % 2 == 0 ? 0.22 : 0.15)
                    let circle = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    context.stroke(circle, with: .color(style.palette.accent), lineWidth: max(unit * 0.08, 0.6))
                    let dot = unit * 0.06
                    context.fill(Path(ellipseIn: CGRect(x: x + step * 0.45 - dot, y: y + step * 0.2 - dot, width: dot * 2, height: dot * 2)),
                                 with: .color(style.palette.accent2))
                    x += step * 1.1
                }
                y += step * 0.75
                row += 1
            }
        }
    }
}

/// Same output for the same seed (SplitMix64).
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
