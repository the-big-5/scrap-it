import CoreGraphics
import Foundation

/// Zoom range and lens values of the active back camera, in display zoom (0.5×, 1×, 2×, …).
/// From the widest lens (0.5× with ultra wide) up to 4× (or the device maximum if lower).
nonisolated struct ZoomCapabilities: Equatable, Sendable {
    static let maxDisplayZoom: CGFloat = 4
    /// Zoom values move in steps of 0.1 (1.0, 1.1, 1.2, …).
    static let step: CGFloat = 0.1
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

    /// Rounds to the nearest 0.1 inside the range (the ends stay reachable even if they are not on 0.1).
    func quantized(_ zoom: CGFloat) -> CGFloat {
        let rounded = ((zoom / Self.step).rounded() * Self.step * 10).rounded() / 10
        return clamped(rounded)
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
        let maxZoom = max(minZoom, min(maxDisplayZoom, maxDeviceFactor / base))

        var presets: [CGFloat] = []
        for lens in lenses.sorted() where lens >= minZoom - 0.01 && lens <= min(2.01, maxZoom + 0.01) {
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
