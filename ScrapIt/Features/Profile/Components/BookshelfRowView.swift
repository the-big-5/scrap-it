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
                            BookSpineView(title: entry.scrapbook.title, style: entry.style)
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

private struct BookSpineView: View {
    static let aspectRatio: CGFloat = 23.68 / 147.84

    let title: String
    let style: BookSpineStyle

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 1.28, style: .continuous)

        DSColorToken(style.backgroundHex).color
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay {
                Image("BookSpineTexture")
                    .resizable()
            }
            .overlay {
                GeometryReader { proxy in
                    Text(title)
                        .dsTypography(DSTypographyToken(family: .architectsDaughter, weight: .regular, size: 9.6, lineHeight: 11))
                        .foregroundStyle(DSColorToken(style.titleHex))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: max(proxy.size.height - 24, 36))
                        .rotationEffect(.degrees(-90))
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
    }
}
