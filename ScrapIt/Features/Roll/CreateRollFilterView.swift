import SwiftUI

/// Pick a filter (change 081, Figma 1571:48191 / 1600:49849): "Create Roll", or "Edit Roll" when the host edits
/// the open roll; Done creates the roll, or saves the edits.
struct CreateRollFilterView: View {
    @Environment(\.dismiss) private var dismiss

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Pick a filter")
                    .font(.system(size: 20))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .padding(.horizontal, 33)
                    .padding(.top, 25)
                    .padding(.bottom, 16)

                // Filter options
                VStack(spacing: 24) {
                    ForEach(RollFilter.allCases) { filter in
                        FilmCanisterFilterRow(
                            filter: filter,
                            isSelected: flowViewModel.draftFilter == filter,
                            samples: flowViewModel.filterSamples[filter] ?? [],
                            onSelect: {
                                withAnimation(.spring(duration: 0.3)) {
                                    flowViewModel.draftFilter = filter
                                }
                            }
                        )
                    }
                }

                Spacer()

                Button("Done") {
                    if flowViewModel.isEditingRoll {
                        flowViewModel.saveRollEdits()
                    } else {
                        flowViewModel.createLobbySession(currentUser: currentUser)
                    }
                }
                .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(flowViewModel.isEditingRoll ? "Edit Roll" : "Create Roll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(DSColor.Brand.primary.color)
        .task { await flowViewModel.loadFilterSamples() }
    }
}
