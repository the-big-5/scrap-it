import Foundation

enum ZoomStop: Double, CaseIterable, Identifiable, Comparable {
    case half = 0.5
    case standard = 1.0
    case double = 2.0

    var id: Double { rawValue }

    var displayValue: String {
        switch self {
        case .half: return "0.5x"
        case .standard: return "1.0x"
        case .double: return "2.0x"
        }
    }

    var sliderIndex: Double {
        switch self {
        case .half: return 0.0
        case .standard: return 1.0
        case .double: return 2.0
        }
    }

    var rotationAngleDegrees: Double {
        switch self {
        case .half: return -45.0
        case .standard: return 0.0
        case .double: return 45.0
        }
    }

    static func < (lhs: ZoomStop, rhs: ZoomStop) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func closest(to factor: Double) -> ZoomStop {
        let sorted = allCases.sorted()
        return sorted.min(by: { abs($0.rawValue - factor) < abs($1.rawValue - factor) }) ?? .standard
    }

    static func closestFromSliderIndex(_ index: Double) -> ZoomStop {
        let sorted = allCases.sorted()
        return sorted.min(by: { abs($0.sliderIndex - index) < abs($1.sliderIndex - index) }) ?? .standard
    }

    static func interpolatedAngle(forSliderIndex index: Double) -> Double {
        let clamped = max(0.0, min(2.0, index))
        // Linear mapping: 0.0 -> -45°, 1.0 -> 0°, 2.0 -> +45°
        return (clamped - 1.0) * 45.0
    }

    func nextClamped() -> ZoomStop {
        let sorted = Self.allCases.sorted()
        guard let index = sorted.firstIndex(of: self) else { return self }
        let nextIndex = min(sorted.count - 1, index + 1)
        return sorted[nextIndex]
    }

    func previousClamped() -> ZoomStop {
        let sorted = Self.allCases.sorted()
        guard let index = sorted.firstIndex(of: self) else { return self }
        let prevIndex = max(0, index - 1)
        return sorted[prevIndex]
    }
}
