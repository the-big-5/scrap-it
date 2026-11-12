import SwiftUI

/// Edit Roll, first step (change 081, Figma 1599:49590): the host changes the name and the shots before the roll
/// starts. Next goes on to the filter (`CreateRollFilterView` in edit mode); ‹ goes back to the lobby unsaved.
struct EditRollSetupView: View {
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    BackCircleButton(action: flowViewModel.cancelEditRoll)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Edit Roll")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)
                    Text("Capture moments with limited shots,\nrevealed when the roll is complete.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DSColor.Brand.primary.color.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Text("Name your roll")
                    .font(.system(size: 20))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .padding(.horizontal, 16)
                    .padding(.top, 44)
                    .padding(.bottom, 12)

                TextField("Bali ’27", text: $flowViewModel.draftRollName)
                    .font(.system(size: 17))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DSColor.Paper.light.color)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DSColor.Brand.primary.color.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)

                Text("Pick how many photos to shot")
                    .font(.system(size: 17))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                    .padding(.bottom, 12)

                FilmStripShotSelector(selectedCount: $flowViewModel.draftShotCount)

                if let guide = RollFlowViewModel.friendsGuide(for: flowViewModel.draftShotCount) {
                    Text(guide)
                        .font(.system(size: 15))
                        .italic()
                        .foregroundStyle(DSColor.Brand.primary.color.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }

                Spacer()

                Button("Next", action: flowViewModel.proceedToFilterStep)
                    .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                    .disabled(!flowViewModel.canProceedFromSetup)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
