import Foundation

/// Color grade of the Digicam look (change 016, from the camera POC): computed once into a 33³ color cube.
/// Input and output are sRGB (gamma) 0–1. Steps: exposure −0.6 EV in linear light, S-curve contrast 0.18
/// around 0.4, warmth (blue ×0.5 in the shadows rising smoothly to ×0.85 in the highlights, smoothstep on
/// luma 0.1–0.8), saturation 1.2 (Rec.709 luma), output mapped to 0.03–0.9 (lifted blacks, cream whites).
nonisolated enum DigicamGrade {
    static let dimension = 33

    static let ev: Double = -0.6            // darker
    static let contrast: Double = 0.18      // S-curve
    static let blueShadow: Double = 0.5     // blue in the shadows (strong warmth)
    static let blueHighlight: Double = 0.85 // blue in the highlights (white turns cream)
    static let saturation: Double = 1.2
    static let lift: Double = 0.03          // darkest black
    static let cap: Double = 0.9            // brightest white

    /// RGBA floats, red fastest, as `CIColorCubeWithColorSpace` expects.
    static let cubeData: Data = {
        let n = dimension
        var values = [Float]()
        values.reserveCapacity(n * n * n * 4)
        for b in 0..<n {
            for g in 0..<n {
                for r in 0..<n {
                    let rgb = apply(Double(r) / Double(n - 1), Double(g) / Double(n - 1), Double(b) / Double(n - 1))
                    values += [Float(rgb.r), Float(rgb.g), Float(rgb.b), 1]
                }
            }
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }()

    static func apply(_ r: Double, _ g: Double, _ b: Double) -> (r: Double, g: Double, b: Double) {
        let gain = pow(2, ev)
        var c = [r, g, b].map { toSRGB(toLinear($0) * gain) }
        c = c.map { x in min(max(x + contrast * sin(.pi * x) * (x - 0.4) * 1.6, 0), 1) }

        let luma = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
        c[2] *= blueShadow + (blueHighlight - blueShadow) * smoothstep(0.1, 0.8, luma)

        let gray = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
        c = c.map { min(max(gray + ($0 - gray) * saturation, 0), 1) }
        c = c.map { lift + (cap - lift) * $0 }
        return (c[0], c[1], c[2])
    }

    private static func toLinear(_ x: Double) -> Double {
        x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
    }

    private static func toSRGB(_ x: Double) -> Double {
        let x = min(max(x, 0), 1)
        return x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055
    }

    private static func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
        let t = min(max((x - e0) / (e1 - e0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
