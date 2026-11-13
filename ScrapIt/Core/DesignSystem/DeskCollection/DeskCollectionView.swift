import SwiftUI

/// Generic, data-agnostic screen container for workbench collection views (e.g., "Resume Editing", "Resume Roll").
struct DeskCollectionView<Content: View, EmptyState: View>: View {
    let title: String
    let isEmpty: Bool
    var horizontalPadding: CGFloat = 23
    let onBack: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let emptyState: () -> EmptyState

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if isEmpty {
                    emptyState()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        content()
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(DSColor.Kraft.lightActive.color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(DSColor.Brand.primary.color)
    }
}
