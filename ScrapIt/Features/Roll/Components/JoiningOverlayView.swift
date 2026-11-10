import SwiftUI

/// Full-screen wait while a roll is being joined by code or invite link (change 024). A film canister bobs and pulls
/// its film strip out and back in; it switches between the B&W and Color canisters every cycle, because the roll's
/// filter isn't known yet. Status text and Cancel come from `RollFlowViewModel`.
struct JoiningOverlayView: View {
    let flowViewModel: RollFlowViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One pull out and back in.
    private static let cycle: TimeInterval = 2.4
    private static let canisterHeight: CGFloat = 132
    /// Strip seen from the side: its width as it lies flat, and the longest part pulled out.
    private static let stripThickness: CGFloat = 70
    private static let stripLength: CGFloat = stripThickness * 1465 / 490

    var body: some View {
        ZStack {
            DSColor.Paper.light.color
                .ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                VStack(spacing: 28) {
                    canisterWithFilm(elapsed: elapsed)
                    Text(flowViewModel.joinStatusText(at: timeline.date))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DSColor.Brand.primary.color)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: flowViewModel.joinStatusText(at: timeline.date))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Joining the roll")

            VStack {
                Spacer()
                Button("Cancel", action: flowViewModel.cancelJoin)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DSColor.Brand.tertiary.color)
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.bottom, 32)
            }
        }
        .transition(.opacity)
    }

    private func canisterWithFilm(elapsed: TimeInterval) -> some View {
        let cycleIndex = Int(elapsed / Self.cycle)
        let phase = elapsed.truncatingRemainder(dividingBy: Self.cycle) / Self.cycle
        // Out, then back in, eased at both ends.
        let pull = reduceMotion ? 1 : (1 - cos(phase * 2 * .pi)) / 2
        let bob = reduceMotion ? 0 : sin(phase * 4 * .pi) * 4
        let filmOpacity = reduceMotion ? 0.35 + 0.65 * (1 - cos(phase * 2 * .pi)) / 2 : 1

        return HStack(spacing: 0) {
            Image(cycleIndex.isMultiple(of: 2) ? "FilterCanisterColor" : "FilterCanisterBW")
                .resizable()
                .scaledToFit()
                .frame(height: Self.canisterHeight)
                .offset(y: bob)
                .zIndex(1)

            // The strip slides out from behind the canister's slit.
            ZStack(alignment: .leading) {
                Image("FilmStripAmber")
                    .resizable()
                    .frame(width: Self.stripThickness, height: Self.stripLength)
                    .rotationEffect(.degrees(-90))
                    .frame(width: Self.stripLength, height: Self.stripThickness)
                    .offset(x: -(1 - pull) * Self.stripLength)
            }
            .frame(width: Self.stripLength, height: Self.stripThickness, alignment: .leading)
            .clipped()
            .opacity(filmOpacity)
            .padding(.leading, -10)
            .offset(y: bob * 0.5)
        }
        .frame(width: Self.canisterHeight * 276 / 440 + Self.stripLength - 10)
        .accessibilityHidden(true)
    }
}
