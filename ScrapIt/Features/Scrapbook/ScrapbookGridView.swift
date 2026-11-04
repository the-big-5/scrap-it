import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ScrapbookGridView: View {
    @Query private var scrapbooks: [Scrapbook]

    let scrapbookID: UUID
    var currentUser: UserProfile
    var viewModel: ScrapbookViewModel

    private var scrapbook: Scrapbook? {
        viewModel.scrapbook(id: scrapbookID, in: scrapbooks)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text(viewModel.title(for: scrapbook))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ScrapTheme.charcoal)

                    HStack {
                        BackCircleButton {
                            viewModel.goBack()
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 16)

                if let scrapbook {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Cover & Metadata Header Card
                            scrapbookHeaderCard(scrapbook)

                            // Basic Grid of Captured Photos + Captions
                            if scrapbook.photos.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 36))
                                        .foregroundStyle(ScrapTheme.secondaryText)
                                    Text("No shots were captured in this roll yet.")
                                        .font(.system(size: 15))
                                        .foregroundStyle(ScrapTheme.secondaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                            } else {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(viewModel.sortedPhotos(of: scrapbook)) { photo in
                                        ScrapbookPhotoCard(photo: photo, viewModel: viewModel)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                } else {
                    Spacer()
                    Text("Scrapbook not found")
                        .foregroundStyle(ScrapTheme.secondaryText)
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func scrapbookHeaderCard(_ scrapbook: Scrapbook) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ScrapTheme.filmStripDark)
                    .frame(width: 76, height: 76)

                if let coverData = scrapbook.coverPhotoData {
                    ScrapDataImageView(data: coverData)
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(scrapbook.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ScrapTheme.charcoal)

                Text(viewModel.dateText(for: scrapbook))
                    .font(.system(size: 13))
                    .foregroundStyle(ScrapTheme.secondaryText)

                Text(viewModel.coOwnersText(for: scrapbook, fallbackName: currentUser.name))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ScrapTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ScrapTheme.charcoal, lineWidth: 1.2)
                )
        )
    }
}
