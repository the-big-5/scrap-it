import SwiftData
import SwiftUI

struct ProfileView: View {
    @Bindable var viewModel: ProfileViewModel

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

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
        ScrollView {
            VStack(spacing: 0) {
                ProfileAvatarView(avatarData: viewModel.avatarData, size: 120)
                    .padding(.top, 56)

                HStack(spacing: 8) {
                    Text(viewModel.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.black)

                    Button(action: viewModel.openEditProfile) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DSColor.Brand.primary.color)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit profile")
                }
                .padding(.top, 12)

                Text(viewModel.bioText)
                    .font(.system(size: 13))
                    .italic(!viewModel.hasBio)
                    .foregroundStyle(viewModel.hasBio ? DSColor.Brand.primary.color : Color.black)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                scrapbookGrid
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 140)
        }
        .background(DSColor.Kraft.lightActive.color.ignoresSafeArea())
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

    /// Covers like the camera POC (change 013), not the Figma shelf yet.
    @ViewBuilder
    private var scrapbookGrid: some View {
        if viewModel.scrapbooks.isEmpty {
            Text(ProfileViewModel.emptyScrapbooksText)
                .font(.system(size: 15))
                .foregroundStyle(ScrapTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
        } else {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.scrapbooks, id: \.id) { scrapbook in
                    Button {
                        viewModel.open(scrapbook)
                    } label: {
                        cover(scrapbook)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.requestDelete(scrapbook)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    /// First page drawn small (still photos only).
    private func cover(_ scrapbook: Scrapbook) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let page = viewModel.coverPage(of: scrapbook) {
                    ScrapbookPageView(
                        page: page,
                        photos: viewModel.photosByID(of: scrapbook),
                        photoAspect: { viewModel.photoAspect(for: $0, in: scrapbook) },
                        showsDrawingImage: true
                    )
                } else {
                    PageBackgroundView(background: .cream)
                        .aspectRatio(3 / 4, contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            .allowsHitTesting(false)

            Text(scrapbook.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ScrapTheme.charcoal)
                .lineLimit(1)
            Text(viewModel.pageCountText(for: scrapbook))
                .font(.caption)
                .foregroundStyle(ScrapTheme.secondaryText)
        }
        .contentShape(Rectangle())
    }
}
