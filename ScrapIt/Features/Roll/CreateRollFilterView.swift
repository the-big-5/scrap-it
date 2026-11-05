import SwiftUI
import SwiftData

struct CreateRollFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            // Header decoration from Figma node 675:5759
            Image("CreateRollHeaderDecoration")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 206)
                .clipped()
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 0) {
                // Top navigation bar with Back button and Title
                ZStack {
                    Text("Create Roll")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)

                    HStack {
                        BackCircleButton {
                            dismiss()
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)

                // Subtitle
                Text("Choose a filter")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // Filter options
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

                // Primary Next Button
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
