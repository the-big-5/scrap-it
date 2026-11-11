import SwiftUI

/// Wooden shelf plank asset from Figma (`1515:31687` / `1300:36435`).
struct WoodShelfPlank: View {
    var body: some View {
        Image("WoodShelf")
            .resizable()
            .aspectRatio(349.0 / 25.0, contentMode: .fit)
            .shadow(color: .black.opacity(0.4), radius: 2.5, x: 0, y: 4)
    }
}

/// One shelf row holding up to 12 vertical scrapbook spines resting on `WoodShelfPlank` (Figma `1300:36434`).
struct BookshelfRowView: View {
    let items: [BookshelfItem]
    let onOpen: (Scrapbook) -> Void
    let onDelete: (Scrapbook) -> Void

    private static let spineSpacing: CGFloat = 3.5

    var body: some View {
        VStack(spacing: -1) {
            HStack(alignment: .bottom, spacing: Self.spineSpacing) {
                ForEach(0..<ProfileViewModel.booksPerShelf, id: \.self) { slot in
                    if items.indices.contains(slot) {
                        let entry = items[slot]
                        Button {
                            onOpen(entry.scrapbook)
                        } label: {
                            BookSpineView(scrapbook: entry.scrapbook)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(entry.scrapbook)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } else {
                        Color.clear
                            .aspectRatio(BookSpineView.aspectRatio, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 13)

            WoodShelfPlank()
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: 420)
    }
}

/// A scrapbook's spine as made in Edit Cover (change 103): the spine art in the cover color with the spine's items
/// (pencil, stickers, text) on top. Nothing on it when the spine was never decorated.
private struct BookSpineView: View {
    static let aspectRatio: CGFloat = 23.68 / 147.84

    let scrapbook: Scrapbook

    var body: some View {
        ZStack {
            BookSpineArt(colorHex: scrapbook.displayedCoverColorHex)
            if let spine = scrapbook.coverPage(.spine) {
                ScrapbookPageView(page: spine, photos: [:], photoAspect: { _ in nil },
                                  aspectRatio: ScrapbookPage.Role.spine.aspectRatio, drawsBackground: false)
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scrapbook.title)
    }
}
