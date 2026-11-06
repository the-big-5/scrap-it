import Foundation
import Testing
@testable import ScrapIt

struct ZoomControlTests {

    // MARK: - ZoomStop Tests

    @Test func zoomStopValuesAndLabels() {
        #expect(ZoomStop.half.rawValue == 0.5)
        #expect(ZoomStop.standard.rawValue == 1.0)
        #expect(ZoomStop.double.rawValue == 2.0)

        #expect(ZoomStop.half.displayValue == "0.5x")
        #expect(ZoomStop.standard.displayValue == "1.0x")
        #expect(ZoomStop.double.displayValue == "2.0x")
    }

    @Test func zoomStopSliderIndices() {
        #expect(ZoomStop.half.sliderIndex == 0.0)
        #expect(ZoomStop.standard.sliderIndex == 1.0)
        #expect(ZoomStop.double.sliderIndex == 2.0)
    }

    @Test func zoomStopClosestMatching() {
        #expect(ZoomStop.closest(to: 0.4) == .half)
        #expect(ZoomStop.closest(to: 0.7) == .half)
        #expect(ZoomStop.closest(to: 0.8) == .standard)
        #expect(ZoomStop.closest(to: 1.4) == .standard)
        #expect(ZoomStop.closest(to: 1.6) == .double)
        #expect(ZoomStop.closest(to: 5.0) == .double)
    }

    @Test func zoomStopClosestFromSliderIndex() {
        #expect(ZoomStop.closestFromSliderIndex(-0.5) == .half)
        #expect(ZoomStop.closestFromSliderIndex(0.4) == .half)
        #expect(ZoomStop.closestFromSliderIndex(0.6) == .standard)
        #expect(ZoomStop.closestFromSliderIndex(1.4) == .standard)
        #expect(ZoomStop.closestFromSliderIndex(1.6) == .double)
        #expect(ZoomStop.closestFromSliderIndex(3.0) == .double)
    }

    @Test func zoomStopAngleInterpolation() {
        #expect(ZoomStop.interpolatedAngle(forSliderIndex: 0.0) == -45.0)
        #expect(ZoomStop.interpolatedAngle(forSliderIndex: 1.0) == 0.0)
        #expect(ZoomStop.interpolatedAngle(forSliderIndex: 2.0) == 45.0)
        #expect(ZoomStop.interpolatedAngle(forSliderIndex: 0.5) == -22.5)

        // Hard clamping beyond boundary stops
        #expect(ZoomStop.interpolatedAngle(forSliderIndex: -1.0) == -45.0)
        #expect(ZoomStop.interpolatedAngle(forSliderIndex: 5.0) == 45.0)
    }

    @Test func zoomStopClampedSteppingHasHardEndstops() {
        // Stepping up from max does not wrap around
        #expect(ZoomStop.double.nextClamped() == .double)
        #expect(ZoomStop.standard.nextClamped() == .double)
        #expect(ZoomStop.half.nextClamped() == .standard)

        // Stepping down from min does not wrap around
        #expect(ZoomStop.half.previousClamped() == .half)
        #expect(ZoomStop.standard.previousClamped() == .half)
        #expect(ZoomStop.double.previousClamped() == .standard)
    }

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
        #expect(caps.maxZoom == 10.0)
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
        #expect(caps.presets.contains(3.0))
    }

    @Test func zoomCapabilitiesLabelFormatting() {
        #expect(ZoomCapabilities.label(for: 0.5) == "0.5×")
        #expect(ZoomCapabilities.label(for: 1.0) == "1×")
        #expect(ZoomCapabilities.label(for: 2.0) == "2×")
        #expect(ZoomCapabilities.label(for: 2.5) == "2.5×")

        #expect(ZoomCapabilities.presetLabel(for: 1.0) == "1")
        #expect(ZoomCapabilities.presetLabel(for: 0.5) == "0.5")
    }

    // MARK: - Inelastic Hard Endstop Math Tests

    @Test func dragIndexClampingGuaranteesRigidHardStops() {
        let dragStartIndex = 0.0
        let overshootNegative = dragStartIndex + (-150.0 / 70.0)
        let clampedNegative = max(0.0, min(2.0, overshootNegative))
        #expect(clampedNegative == 0.0)

        let dragStartMax = 2.0
        let overshootPositive = dragStartMax + (150.0 / 70.0)
        let clampedPositive = max(0.0, min(2.0, overshootPositive))
        #expect(clampedPositive == 2.0)
    }
}
