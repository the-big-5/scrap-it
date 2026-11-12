import Foundation
import Testing
@testable import ScrapIt

struct ZoomControlTests {

    // MARK: - ZoomCapabilities Tests

    @Test func zoomCapabilitiesWithoutUltraWide() {
        let caps = ZoomCapabilities.make(
            hasUltraWide: false,
            switchOverFactors: [2.0],
            secondaryNativeFactors: [],
            minDeviceFactor: 1.0,
            maxDeviceFactor: 10.0
        )

        #expect(caps.base == 1.0)
        #expect(caps.minZoom == 1.0)
        #expect(caps.maxZoom == 4.0, "Capped at 4x")
        #expect(caps.deviceFactor(forDisplayZoom: 2.0) == 2.0)
        #expect(caps.clamped(0.5) == 1.0)
        #expect(caps.clamped(3.0) == 3.0)
    }

    @Test func zoomCapabilitiesWithUltraWide() {
        // Ultra wide base: 2.0 switchover means device 1.0 is 0.5x, device 2.0 is 1.0x, device 6.0 is 3.0x
        let caps = ZoomCapabilities.make(
            hasUltraWide: true,
            switchOverFactors: [2.0, 6.0],
            secondaryNativeFactors: [],
            minDeviceFactor: 1.0,
            maxDeviceFactor: 12.0
        )

        #expect(caps.base == 2.0)
        #expect(caps.minZoom == 0.5)
        #expect(caps.deviceFactor(forDisplayZoom: 0.5) == 1.0)
        #expect(caps.deviceFactor(forDisplayZoom: 1.0) == 2.0)
        #expect(caps.deviceFactor(forDisplayZoom: 2.0) == 4.0)
        #expect(caps.presets.contains(0.5))
        #expect(caps.presets.contains(1.0))
        #expect(!caps.presets.contains(3.0), "Telephoto presets above 2.0x are excluded")
    }

    // MARK: - Change 008 & 060: range up to 4x, 0.1 steps, telephoto excluded

    @Test func maxZoomIsFour() {
        let caps = ZoomCapabilities.make(
            hasUltraWide: true,
            switchOverFactors: [2.0, 8.0],
            secondaryNativeFactors: [],
            minDeviceFactor: 1.0,
            maxDeviceFactor: 270.0
        )

        #expect(caps.minZoom == 0.5)
        #expect(caps.maxZoom == 4.0)
        #expect(caps.presets == [0.5, 1.0])
    }

    @Test func minZoomWithoutUltraWideIsOne() {
        let caps = ZoomCapabilities.make(
            hasUltraWide: false,
            switchOverFactors: [],
            secondaryNativeFactors: [],
            minDeviceFactor: 1.0,
            maxDeviceFactor: 16.0
        )

        #expect(caps.minZoom == 1.0)
        #expect(caps.maxZoom == 4.0)
        #expect(caps.presets == [1.0])
    }

    @Test(arguments: [
        (1.04, 1.0), (1.05, 1.1), (1.26, 1.3), (2.94, 2.9), (0.43, 0.5), (200.0, 4.0),
    ])
    func zoomSnapsToTenths(_ input: Double, _ expected: Double) {
        let caps = ZoomCapabilities.make(
            hasUltraWide: true,
            switchOverFactors: [2.0, 8.0],
            secondaryNativeFactors: [],
            minDeviceFactor: 1.0,
            maxDeviceFactor: 270.0
        )

        #expect(abs(caps.quantized(CGFloat(input)) - CGFloat(expected)) < 0.0001)
    }

    @Test func lowerDeviceMaxIsRespected() {
        let caps = ZoomCapabilities.make(
            hasUltraWide: false,
            switchOverFactors: [],
            secondaryNativeFactors: [],
            minDeviceFactor: 1.0,
            maxDeviceFactor: 3.0
        )

        #expect(caps.maxZoom == 3.0)
    }

    @Test func lensesAboveMaxAreNotOffered() {
        // 0.5x / 1x / 2x / 8x telephoto (base 2): the 8x lens is past the 4x max.
        let caps = ZoomCapabilities.make(
            hasUltraWide: true,
            switchOverFactors: [2.0, 4.0, 16.0],
            secondaryNativeFactors: [],
            minDeviceFactor: 1.0,
            maxDeviceFactor: 300.0
        )

        #expect(caps.presets == [0.5, 1.0, 2.0])
    }

    @Test func zoomCapabilitiesLabelFormatting() {
        #expect(ZoomCapabilities.label(for: 0.5) == "0.5×")
        #expect(ZoomCapabilities.label(for: 1.0) == "1×")
        #expect(ZoomCapabilities.label(for: 2.0) == "2×")
        #expect(ZoomCapabilities.label(for: 2.5) == "2.5×")

        #expect(ZoomCapabilities.presetLabel(for: 1.0) == "1")
        #expect(ZoomCapabilities.presetLabel(for: 0.5) == "0.5")
    }

    // MARK: - Change 060: ZoomStop Discrete Stepping Tests

    @Test func zoomStopDiscreteStepProgression() {
        #expect(ZoomStop.totalSteps == 36)
        #expect(ZoomStop.allCases.count == 36)

        let first = ZoomStop.from(stepIndex: 0)
        #expect(first.rawValue == 0.5)
        #expect(first.stepIndex == 0)

        let standard = ZoomStop.from(stepIndex: 5)
        #expect(standard.rawValue == 1.0)
        #expect(standard.stepIndex == 5)

        let double = ZoomStop.from(stepIndex: 15)
        #expect(double.rawValue == 2.0)
        #expect(double.stepIndex == 15)

        let triple = ZoomStop.from(stepIndex: 25)
        #expect(triple.rawValue == 3.0)
        #expect(triple.stepIndex == 25)

        let last = ZoomStop.from(stepIndex: 35)
        #expect(last.rawValue == 4.0)
        #expect(last.stepIndex == 35)
    }

    @Test func zoomStopMilestonesAndProgress() {
        let milestones = ZoomStop.milestoneStops
        #expect(milestones.count == 5)
        #expect(milestones.map(\.rawValue) == [0.5, 1.0, 2.0, 3.0, 4.0])

        #expect(ZoomStop.half.progress == 0.0)
        #expect(abs(ZoomStop.standard.progress - (5.0 / 35.0)) < 0.0001)
        #expect(abs(ZoomStop.double.progress - (15.0 / 35.0)) < 0.0001)
        #expect(abs(ZoomStop.triple.progress - (25.0 / 35.0)) < 0.0001)
        #expect(ZoomStop.quadruple.progress == 1.0)
    }

    @Test func zoomStopClampingAndBoundaryLimits() {
        let atMin = ZoomStop.half
        #expect(atMin.previousClamped() == atMin)

        let atMax = ZoomStop.quadruple
        #expect(atMax.nextClamped() == atMax)

        // Custom device limits without ultra wide (min 1.0x, step 5)
        let minStepWithoutUltraWide = ZoomStop.standard.stepIndex
        let clampedDown = ZoomStop.standard.previousClamped(minStepIndex: minStepWithoutUltraWide)
        #expect(clampedDown == ZoomStop.standard)
    }

    @Test func zoomStopRotationAngleMapping() {
        #expect(abs(ZoomStop.half.rotationAngleDegrees - (-60.0)) < 0.0001)
        #expect(abs(ZoomStop.quadruple.rotationAngleDegrees - 60.0) < 0.0001)
        #expect(abs(ZoomStop.standard.rotationAngleDegrees - ((5.0 / 35.0 - 0.5) * 120.0)) < 0.0001)
    }

    @Test func zoomStopDisplayFormatting() {
        #expect(ZoomStop.half.displayValue == "0.5×")
        #expect(ZoomStop.standard.displayValue == "1×")
        #expect(ZoomStop.double.displayValue == "2×")
        #expect(ZoomStop.from(factor: 1.5).displayValue == "1.5×")
        #expect(ZoomStop.quadruple.displayValue == "4×")
    }
}
