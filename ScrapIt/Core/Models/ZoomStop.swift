import Foundation

/// Discrete camera zoom stops from 0.5× to 4.0× in 0.1× increments (36 steps).
/// Ported from `zoom-control-animation` for direct discrete dial stepping and synchronized haptics.
nonisolated struct ZoomStop: Identifiable, Comparable, Hashable, Sendable {
    let rawValue: Double
    let stepIndex: Int

    var id: Double { rawValue }

    static let minFactor: Double = 0.5
    static let maxFactor: Double = 4.0
    static let stepSize: Double = 0.1
    static let totalSteps: Int = 36 // 0...35 for 0.5x to 4.0x

    static let standard = ZoomStop.from(factor: 1.0)
    static let half = ZoomStop.from(factor: 0.5)
    static let double = ZoomStop.from(factor: 2.0)
    static let triple = ZoomStop.from(factor: 3.0)
    static let quadruple = ZoomStop.from(factor: 4.0)

    static let allCases: [ZoomStop] = (0..<totalSteps).map { index in
        ZoomStop.from(stepIndex: index)
    }

    static let milestoneStops: [ZoomStop] = [
        ZoomStop.from(factor: 0.5),
        ZoomStop.from(factor: 1.0),
        ZoomStop.from(factor: 2.0),
        ZoomStop.from(factor: 3.0),
        ZoomStop.from(factor: 4.0)
    ]

    var displayValue: String {
        if abs(rawValue - rawValue.rounded()) < 0.001 {
            return "\(Int(rawValue.rounded()))×"
        }
        return String(format: "%.1f×", rawValue)
    }

    var progress: Double {
        Double(stepIndex) / Double(Self.totalSteps - 1)
    }

    /// Discrete rotation angle mapped from -60° at 0.5× to +60° at 4.0×
    var rotationAngleDegrees: Double {
        (progress - 0.5) * 120.0
    }

    static func from(stepIndex: Int) -> ZoomStop {
        let clampedIndex = max(0, min(totalSteps - 1, stepIndex))
        let factor = minFactor + Double(clampedIndex) * stepSize
        let rounded = (factor * 10.0).rounded() / 10.0
        return ZoomStop(rawValue: rounded, stepIndex: clampedIndex)
    }

    static func from(factor: Double) -> ZoomStop {
        let clamped = max(minFactor, min(maxFactor, factor))
        let step = Int(((clamped - minFactor) / stepSize).rounded())
        return from(stepIndex: step)
    }

    static func closest(to factor: Double) -> ZoomStop {
        from(factor: factor)
    }

    func nextClamped(maxStepIndex: Int = totalSteps - 1) -> ZoomStop {
        let nextIndex = min(maxStepIndex, stepIndex + 1)
        return Self.from(stepIndex: nextIndex)
    }

    func previousClamped(minStepIndex: Int = 0) -> ZoomStop {
        let prevIndex = max(minStepIndex, stepIndex - 1)
        return Self.from(stepIndex: prevIndex)
    }

    static func < (lhs: ZoomStop, rhs: ZoomStop) -> Bool {
        lhs.stepIndex < rhs.stepIndex
    }
}
