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
                header

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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.black)
                .lineLimit(1)

            HStack {
                BackCircleButton(action: onBack)
                    .accessibilityLabel("Back")
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
