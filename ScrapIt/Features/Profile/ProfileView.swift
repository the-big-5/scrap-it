import SwiftData
import SwiftUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    var onSignOut: () -> Void

    init(modelContext: ModelContext, currentUser: UserProfile, onSignOut: @escaping () -> Void) {
        _viewModel = State(initialValue: ProfileViewModel(modelContext: modelContext, currentUser: currentUser))
        self.onSignOut = onSignOut
    }

    init(viewModel: ProfileViewModel, onSignOut: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSignOut = onSignOut
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Circle()
                .fill(ScrapTheme.charcoal.opacity(0.12))
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(ScrapTheme.charcoal)
                )

            Text(viewModel.displayName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(ScrapTheme.charcoal)

            Text(viewModel.scrapbookCountText)
                .font(.system(size: 15))
                .foregroundStyle(ScrapTheme.secondaryText)

            Text(viewModel.statusText)
                .font(.system(size: 13))
                .foregroundStyle(ScrapTheme.secondaryText.opacity(0.8))
                .padding(.top, 8)

            // Temporary until the Profile design is ready (change 004).
            DSButton("Sign Out", variant: .secondary, action: onSignOut)
                .padding(.top, 8)
            Spacer()
        }
    }
}
