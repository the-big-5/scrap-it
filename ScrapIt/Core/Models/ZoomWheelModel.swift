import CoreGraphics
import Foundation

/// Drag-to-zoom math for the knurled zoom wheel, modeled on sliding Camera Control:
/// - dragging **left** zooms in, right zooms out
/// - logarithmic scale: 1×→2× takes the same travel as 2×→4×
/// - slow drags move 0.1 at a time; faster drags cover more steps
/// - a light detent at each lens value (0.5×, 1×, 2×, …) when dragging slowly
/// - hard endstops at the device's min and max zoom, no bounce
nonisolated struct ZoomWheelModel: Equatable, Sendable {
    /// Drag distance (points) that doubles or halves the zoom at slow speed.
    static let pointsPerDoubling: Double = 110
    /// Below this speed (points/second) one point of drag is one point of travel.
    static let slowSpeed: Double = 150
    /// Extra speed (points/second) that adds 1× more travel.
    static let speedPerGain: Double = 250
    static let maxGain: Double = 8
    /// Drag needed to leave a lens value after stopping on it.
    static let detentPoints: Double = 10

    struct Update: Equatable, Sendable {
        /// Number of 0.1 steps passed (for haptic ticks).
        var steps = 0
        /// Stopped on or passed a lens value.
        var hitLens = false
        /// Hit the min or max zoom (fires once per collision).
        var hitEndstop = false
    }

    private(set) var capabilities: ZoomCapabilities
    /// Natural log of the unquantized zoom.
    private var logZoom: Double
    private var detentRemaining: Double = 0
    private var isAtEndstop = false

    init(capabilities: ZoomCapabilities, zoom: CGFloat = 1) {
        self.capabilities = capabilities
        self.logZoom = log(Double(capabilities.clamped(zoom)))
    }

    /// Zoom shown and applied to the camera, on 0.1 steps.
    var zoom: CGFloat {
        capabilities.quantized(CGFloat(exp(logZoom)))
    }

    var isZoomable: Bool { capabilities.isZoomable }

    /// Wheel travel in points; increases as the zoom increases.
    var travel: Double {
        logZoom / log(2) * Self.pointsPerDoubling
    }

    /// Rib offset for drawing: ribs follow the finger (zooming in moves them left).
    func ribOffset(spacing: Double) -> Double {
        Self.ribOffset(travel: travel, spacing: spacing)
    }

    static func ribOffset(travel: Double, spacing: Double) -> Double {
        -travel.truncatingRemainder(dividingBy: spacing)
    }

    static func gain(forSpeed speed: Double) -> Double {
        let extra = max(0, abs(speed) - slowSpeed) / speedPerGain
        return min(maxGain, 1 + extra)
    }

    /// `dx` is the horizontal finger movement since the last call (negative = left),
    /// `velocity` the current horizontal speed in points/second.
    mutating func drag(by dx: Double, velocity: Double) -> Update {
        var update = Update()
        guard isZoomable, dx != 0 else { return update }

        let gain = Self.gain(forSpeed: velocity)
        var distance = -dx
        if detentRemaining > 0, gain == 1 {
            let used = min(detentRemaining, abs(distance))
            detentRemaining -= used
            distance = distance > 0 ? distance - used : distance + used
            if distance == 0 { return update }
        }
        detentRemaining = 0

        let before = zoom
        let beforeRaw = exp(logZoom)
        var newLog = logZoom + distance * gain * log(2) / Self.pointsPerDoubling
        let minLog = log(Double(capabilities.minZoom))
        let maxLog = log(Double(capabilities.maxZoom))

        if newLog <= minLog || newLog >= maxLog {
            newLog = min(max(newLog, minLog), maxLog)
            if !isAtEndstop {
                update.hitEndstop = true
                isAtEndstop = true
            }
        } else {
            isAtEndstop = false
        }

        let afterRaw = exp(newLog)
        if let lens = Self.lensCrossed(from: beforeRaw, to: afterRaw, lenses: capabilities.presets) {
            update.hitLens = true
            if gain == 1 {
                newLog = log(Double(lens))
                detentRemaining = Self.detentPoints
            }
        }

        logZoom = newLog
        update.steps = Int((abs(zoom - before) / ZoomCapabilities.step).rounded())
        return update
    }

    /// Jumps to a zoom set elsewhere (Camera Control, camera flip).
    mutating func sync(to zoom: CGFloat) {
        logZoom = log(Double(capabilities.clamped(zoom)))
        detentRemaining = 0
        isAtEndstop = false
    }

    mutating func update(capabilities: ZoomCapabilities, zoom: CGFloat) {
        self.capabilities = capabilities
        sync(to: zoom)
    }

    /// Next lens value in the zoom-in (`true`) or zoom-out direction, or `nil` at the end.
    func nextLens(zoomingIn: Bool) -> CGFloat? {
        let current = zoom
        if zoomingIn {
            return capabilities.presets.first { $0 > current + 0.05 }
        }
        return capabilities.presets.last { $0 < current - 0.05 }
    }

    /// First lens value strictly passed or landed on when moving from `a` to `b` (exclusive of `a`).
    private static func lensCrossed(from a: Double, to b: Double, lenses: [CGFloat]) -> CGFloat? {
        guard a != b else { return nil }
        let tolerance = 0.0001
        if b > a {
            return lenses.first { Double($0) > a + tolerance && Double($0) <= b + tolerance }
        }
        return lenses.last { Double($0) < a - tolerance && Double($0) >= b - tolerance }
    }
}
