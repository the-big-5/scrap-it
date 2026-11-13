import SwiftUI

struct CreateRollSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Large Title and Subtitle (Figma 1717:68794)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Roll")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)

                    Text("Capture moments with limited shots,\nrevealed when the roll is complete.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DSColor.Brand.primary.color.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Section 1: Name your roll
                VStack(alignment: .leading, spacing: 12) {
                    Text("Name your roll")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color.black)

                    TextField(
                        "",
                        text: $flowViewModel.draftRollName,
                        prompt: Text("A trip, a night out, a season.")
                            .font(.system(size: 15))
                            .italic()
                            .foregroundStyle(Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255, opacity: 0.3))
                    )
                    .font(.system(size: 17))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.black, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 36)

                // Section 2: Pick how many photos to shot
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pick how many photos to shot")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 16)

                    FilmStripShotSelector(selectedCount: $flowViewModel.draftShotCount)

                    // Guidance for the picked count; nothing before a pick (change 081).
                    if let guide = RollFlowViewModel.friendsGuide(for: flowViewModel.draftShotCount) {
                        HStack {
                            Spacer()
                            Text(guide)
                                .font(.system(size: 15, weight: .regular))
                                .italic()
                                .foregroundStyle(DSColor.Brand.primary.color.opacity(0.6))
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.top, 34)

                Spacer()

                // Next waits for a name and a shot count, in the disabled color until then (change 081).
                Button("Next") {
                    flowViewModel.proceedToFilterStep()
                }
                .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                .disabled(!flowViewModel.canProceedFromSetup)
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .tint(DSColor.Brand.primary.color)
    }
}
