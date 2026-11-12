import SwiftUI

struct RollClusterBounceState: Equatable {
    var scale: CGFloat = 1.0
    var spread: CGFloat = 0.0
    var wiggleDegrees: Double = 0.0
}

/// Interactive 3-canister cluster on the Workbench that fans cleanly from its resting mat corner
/// into the highlighted Figma 1235:21168 center cluster before navigating to "Resume Roll".
struct InteractiveRollsView: View {
    let placements: [WorkbenchRollPlacement]
    let layout: WorkbenchLayout
    let isActive: Bool
    let isObscured: Bool
    let isDisabled: Bool
    let bounce: RollClusterBounceState
    let onTap: () -> Void

    private static let spreadDirections: [CGSize] = [
        CGSize(width: 4, height: -5),
        CGSize(width: 5, height: 4),
        CGSize(width: -5, height: 2),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(placements.enumerated()), id: \.element.asset) { index, canister in
                canisterButton(canister, index: index)
            }
        }
        .allowsHitTesting(!isActive && !isDisabled)
        .blur(radius: isObscured ? layout.length(10) : 0)
        .opacity(isObscured ? 0.55 : 1)
    }

    private func canisterButton(_ canister: WorkbenchRollPlacement, index: Int) -> some View {
        let size = layout.size(isActive ? canister.activeSize : canister.idleSize)
        let targetCenter = layout.point(isActive ? canister.activeCenter : canister.idleCenter)
        let baseRotation = isActive ? canister.activeRotation : canister.idleRotation
        let direction = index < Self.spreadDirections.count ? Self.spreadDirections[index] : .zero
        let wiggleSign = index.isMultiple(of: 2) ? 1.0 : -1.0

        return Button(action: onTap) {
            Image(canister.asset)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .shadow(
                    color: .black.opacity(isActive ? 0.28 : 0.25),
                    radius: layout.length(isActive ? 10 : 5),
                    x: 0,
                    y: layout.length(4)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Film Rolls")
        .accessibilityHint("Tap to view and resume your in-progress rolls")
        .disabled(isDisabled && !isActive)
        .scaleEffect(isActive ? bounce.scale : 1.0)
        .rotationEffect(.degrees(baseRotation + (isActive ? bounce.wiggleDegrees * wiggleSign : 0)))
        .offset(
            x: isActive ? layout.length(direction.width * bounce.spread) : 0,
            y: isActive ? layout.length(direction.height * bounce.spread) : 0
        )
        .position(targetCenter)
    }
}
