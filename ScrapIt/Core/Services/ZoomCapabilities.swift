import CoreGraphics
import Foundation

struct ZoomCapabilities: Equatable {
    static let digitalZoomMultiplier: CGFloat = 5
    static let maxDisplayZoom: CGFloat = 10
    private static let mergeTolerance: CGFloat = 0.1

    static let none = ZoomCapabilities(base: 1, minZoom: 1, maxZoom: 1, presets: [1])

    let base: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let presets: [CGFloat]

    var isZoomable: Bool {
        maxZoom > minZoom
    }

    func clamped(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, minZoom), maxZoom)
    }

    func deviceFactor(forDisplayZoom zoom: CGFloat) -> CGFloat {
        clamped(zoom) * base
    }

    func displayZoom(forDeviceFactor factor: CGFloat) -> CGFloat {
        clamped(factor / base)
    }

    func activePreset(for zoom: CGFloat) -> CGFloat? {
        presets.last { $0 <= zoom + 0.05 } ?? presets.first
    }

    static func make(
        hasUltraWide: Bool,
        switchOverFactors: [CGFloat],
        secondaryNativeFactors: [CGFloat],
        minDeviceFactor: CGFloat,
        maxDeviceFactor: CGFloat
    ) -> ZoomCapabilities {
        let base = hasUltraWide ? (switchOverFactors.first ?? 1) : 1

        var lenses: [CGFloat] = [1]
        if hasUltraWide {
            lenses.append(1 / base)
        }
        let telephotoSwitchOvers = hasUltraWide ? Array(switchOverFactors.dropFirst()) : switchOverFactors
        lenses += telephotoSwitchOvers.map { $0 / base }

        for factor in secondaryNativeFactors {
            lenses.append(factor / base >= 1.5 ? factor / base : factor)
        }

        let minZoom = minDeviceFactor / base
        let longestLens = lenses.max() ?? 1
        let maxZoom = max(minZoom, min(longestLens * digitalZoomMultiplier, maxDisplayZoom, maxDeviceFactor / base))

        var presets: [CGFloat] = []
        for lens in lenses.sorted() where lens >= minZoom - 0.01 && lens <= maxZoom + 0.01 {
            if let last = presets.last, lens - last < mergeTolerance { continue }
            presets.append(lens)
        }
        return ZoomCapabilities(base: base, minZoom: minZoom, maxZoom: maxZoom, presets: presets.isEmpty ? [1] : presets)
    }

    static func label(for zoom: CGFloat) -> String {
        let rounded = (zoom * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.01 {
            return "\(Int(rounded.rounded()))×"
        }
        return String(format: "%.1f×", rounded)
    }

    static func presetLabel(for zoom: CGFloat) -> String {
        String(label(for: zoom).dropLast())
    }
}
