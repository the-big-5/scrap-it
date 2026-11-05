import SwiftUI

struct CreateRollSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            // Header decoration from Figma node 984:3556
            Image("CreateRollHeaderDecoration")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 206)
                .clipped()
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 0) {
                // Top navigation bar with Back button
                HStack {
                    BackCircleButton {
                        dismiss()
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Large Title and Subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Roll")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)

                    Text("Capture moments with limited shots,\nrevealed when the roll is complete.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DSColor.Brand.primary.color.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 28)

                // Section 1: Name your roll
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name your roll")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DSColor.Brand.primary.color)

                    Text("A trip, a night out, a season.")
                        .font(.system(size: 15, weight: .regular))
                        .italic()
                        .foregroundStyle(DSColor.Brand.primary.color.opacity(0.6))
                        .padding(.bottom, 6)

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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)

                // Section 2: Choose your shots
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose your shots.")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DSColor.Brand.primary.color)

                    Text("How many memories?")
                        .font(.system(size: 15, weight: .regular))
                        .italic()
                        .foregroundStyle(DSColor.Brand.primary.color.opacity(0.6))
                        .padding(.bottom, 12)

                    FilmStripShotSelector(selectedCount: $flowViewModel.draftShotCount)

                    HStack {
                        Spacer()
                        Text(friendsGuide(for: flowViewModel.draftShotCount))
                            .font(.system(size: 15, weight: .regular))
                            .italic()
                            .foregroundStyle(DSColor.Brand.primary.color.opacity(0.6))
                        Spacer()
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Primary Next Button
                Button("Next") {
                    flowViewModel.proceedToFilterStep()
                }
                .buttonStyle(OffsetPillButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func friendsGuide(for shots: Int) -> String {
        switch shots {
        case 24:
            return "2-4 friends"
        case 36:
            return "4-6 friends"
        case 48:
            return "6-8 friends"
        case 72:
            return "8-12 friends"
        default:
            return "A small circle"
        }
    }
}
