import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct CreateRollStep2FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var currentUser: UserProfile
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
                .padding(.bottom, 34)

                Text("Choose a filter")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ScrapTheme.charcoal)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 18)

                VStack(spacing: 24) {
                    ForEach(RollFilter.allCases) { filter in
                        FilmCanisterFilterRow(
                            filter: filter,
                            isSelected: flowViewModel.draftFilter == filter,
                            onSelect: {
                                withAnimation(.spring(duration: 0.3)) {
                                    flowViewModel.draftFilter = filter
                                }
                            }
                        )
                    }
                }

                Spacer()

                Button("Next") {
                    flowViewModel.createLobbySession(
                        currentUser: currentUser,
                        modelContext: modelContext
                    )
                }
                .buttonStyle(OffsetPillButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
