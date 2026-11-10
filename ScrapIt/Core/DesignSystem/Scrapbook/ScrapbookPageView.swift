import SwiftUI

/// What the editor can do with an item. `nil` on read-only pages (covers).
struct ScrapbookItemActions {
    var select: (UUID) -> Void
    /// Item id, translation (page points), scale, rotation delta (radians), page size.
    var commitTransform: (UUID, CGSize, CGFloat, Double, CGSize) -> Void
    var bringToFront: (UUID) -> Void
    var sendToBack: (UUID) -> Void
    var toggleMotion: (UUID) -> Void
    var remove: (UUID) -> Void
    var deselect: () -> Void
    /// Double tap: full-screen photo, or edit a text (change 022).
    var doubleTap: (UUID) -> Void = { _ in }
    var editText: (UUID) -> Void = { _ in }
}

/// A 3:4 scrapbook page: background, then its items back to front (change 013, POC look).
struct ScrapbookPageView: View {
    static let coordinateSpace = "scrapbookPage"

    let page: ScrapbookPage
    let photos: [UUID: ScrapPhoto]
    var selectedItemID: UUID?
    var photoAspect: (ScrapbookItem) -> CGFloat?
    var shouldPlay: (ScrapbookItem, Bool) -> Bool = { _, _ in false }
    var actions: ScrapbookItemActions?
    /// Covers draw the PencilKit layer as an image; the editor puts a live canvas on top instead.
    var showsDrawingImage = false
    /// Swipe left / right on an empty area: -1 previous page, +1 next page. `nil` = off (change 022).
    var onSwipePage: ((Int) -> Void)?
    /// The drawing layer being drawn (hidden; the canvas replaces it).
    var activeDrawingID: UUID?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PageBackgroundView(background: page.pageBackground)
                    .onTapGesture { actions?.deselect() }
                    .gesture(swipe, including: onSwipePage == nil ? .none : .all)

                ForEach(page.sortedItems, id: \.id) { item in
                    ScrapbookItemView(
                        item: item,
                        photo: item.photoID.flatMap { photos[$0] },
                        photoAspect: photoAspect(item),
                        pageSize: geometry.size,
                        isSelected: selectedItemID == item.id,
                        shouldPlay: { shouldPlay(item, $0) },
                        actions: actions,
                        isHidden: item.id == activeDrawingID
                    )
                }

                if showsDrawingImage {
                    ScrapbookDrawingImage(data: page.drawingData)
                }
            }
            .coordinateSpace(name: Self.coordinateSpace)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipped()
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 60, abs(dx) > abs(value.translation.height) * 1.5 else { return }
                onSwipePage?(dx < 0 ? 1 : -1)
            }
    }
}
