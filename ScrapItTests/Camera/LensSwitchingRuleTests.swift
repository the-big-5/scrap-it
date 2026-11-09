import Testing
@testable import ScrapIt

/// Change 018: Pro iPhones must not switch lenses for close subjects; only zooming may switch lenses.
struct LensSwitchingRuleTests {
    @Test func virtualBackCameraIsLockedBetweenZooms() {
        #expect(LensSwitchingRule.resolve(isBackCamera: true, isVirtualDevice: true, supportsSwitchingBehavior: true)
                == .lockedBetweenZooms)
    }

    @Test(arguments: [
        (false, true, true),   // front camera
        (true, false, true),   // single-lens back camera
        (true, true, false),   // virtual camera without switching support
    ])
    func otherCamerasAreLeftAlone(_ isBack: Bool, _ isVirtual: Bool, _ supported: Bool) {
        #expect(LensSwitchingRule.resolve(isBackCamera: isBack, isVirtualDevice: isVirtual, supportsSwitchingBehavior: supported)
                == .unchanged)
    }
}
