import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct CreateRollStep1View: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                ZStack {
                    Text("Create Roll")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ScrapTheme.charcoal)

                    HStack {
                        BackCircleButton {
                            dismiss()
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 42)

                // Roll Name Input
                VStack(alignment: .leading, spacing: 10) {
                    Text("Give this roll a name")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(ScrapTheme.charcoal)

                    TextField("Value", text: $flowViewModel.draftRollName)
                        .font(.system(size: 16))
                        .foregroundStyle(ScrapTheme.charcoal)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(ScrapTheme.charcoal, lineWidth: 1.2)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 34)

                // Number of Shots Film Strip Selector
                Text("Select the number of shots")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(ScrapTheme.charcoal)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)

                FilmStripShotSelector(selectedCount: $flowViewModel.draftShotCount)

                Spacer()

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
}
