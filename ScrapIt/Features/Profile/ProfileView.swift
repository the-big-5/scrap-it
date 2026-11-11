import SwiftData
import SwiftUI

struct ProfileView: View {
    @Bindable var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }

    init(
        modelContext: ModelContext,
        currentUser: UserProfile,
        navigator: (any Navigator)? = nil,
        onSignOut: @escaping () -> Void = {}
    ) {
        self.viewModel = ProfileViewModel(
            modelContext: modelContext,
            currentUser: currentUser,
            navigator: navigator,
            onSignOut: onSignOut
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ProfileAvatarView(avatarData: viewModel.avatarData, size: 120)
                        .padding(.top, 56)

                    Text(viewModel.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.black)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)

                    Text(viewModel.bioText)
                        .font(.system(size: 13))
                        .italic(!viewModel.hasBio)
                        .foregroundStyle(viewModel.hasBio ? DSColor.Brand.primary.color : Color.black)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)

                    bookshelfSection
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
            }

            moreMenu
                .padding(.top, 4)
                .padding(.trailing, 16)
        }
        .onAppear { viewModel.reload() }
        .confirmationDialog(
            "Delete this scrapbook?",
            isPresented: Binding(
                get: { viewModel.scrapbookPendingDeletion != nil },
                set: { if !$0 { viewModel.scrapbookPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Scrapbook", role: .destructive, action: viewModel.confirmDelete)
        } message: {
            Text("Its photos on this phone are deleted too.")
        }
    }

    private var moreMenu: some View {
        Menu {
            Button(action: viewModel.openEditProfile) {
                Label("Profile Settings", systemImage: "gear")
            }
            Button(action: {}) {
                Label("Share Profile", systemImage: "square.and.arrow.up")
            }
            .disabled(true)
        } label: {
            CircleIconLabel(systemName: "ellipsis")
        }
        .accessibilityLabel("Profile options")
    }

    @ViewBuilder
    private var bookshelfSection: some View {
        if viewModel.shelfRows.isEmpty {
            VStack(spacing: 0) {
                Text(ProfileViewModel.emptyBookshelfText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.center)

                Button(action: viewModel.openCreateRoll) {
                    Text("Create Roll")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DSColor.Paper.lightHover)
                        .frame(width: 217, height: 52)
                        .background(Capsule().fill(DSColor.Brand.primary))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)

                WoodShelfPlank()
                    .padding(.horizontal, 26)
                    .frame(maxWidth: 420)
                    .padding(.top, 19)
            }
            .padding(.top, 96)
        } else {
            LazyVStack(spacing: 46) {
                ForEach(Array(viewModel.shelfRows.enumerated()), id: \.offset) { _, row in
                    BookshelfRowView(
                        items: row,
                        onOpen: viewModel.open,
                        onDelete: viewModel.requestDelete
                    )
                }
            }
            .padding(.top, 76)
        }
    }
}
