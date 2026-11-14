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
    /// A tap on the paper (point and page size): may pick a pencil drawing (change 150). `nil` = `deselect`.
    var tapPaper: ((CGPoint, CGSize) -> Void)?
    /// Double tap: full-screen photo, or edit a text (change 022).
    var doubleTap: (UUID) -> Void = { _ in }
    var editText: (UUID) -> Void = { _ in }
    var dragChanged: (UUID, CGPoint) -> Void = { _, _ in }
    var endDrag: (UUID) -> Bool = { _ in false }
    var cancelDrag: (UUID) -> Void = { _ in }
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
    /// The drawing layer being drawn (hidden; the canvas replaces it).
    var activeDrawingID: UUID?
    /// Active dragged item and trash hover state (unclips the dragged item over page bounds).
    var draggedItemID: UUID?
    var isTrashTargeted = false
    /// Width / height: 3:4 for pages; the front cover and the spine have their own shape (change 026).
    var aspectRatio: CGFloat = 3 / 4
    /// Cover sides draw the cover art behind instead of the paper (change 026).
    var drawsBackground = true
    /// Drawing layers shown with other data, by item (a selected pencil drawing, change 150).
    var drawingDataOverrides: [UUID: Data] = [:]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Group {
                    if drawsBackground {
                        PageBackgroundView(background: page.pageBackground)
                    } else {
                        Color.clear.contentShape(Rectangle())
                    }
                }
                .onTapGesture { location in
                    if let tapPaper = actions?.tapPaper {
                        tapPaper(location, geometry.size)
                    } else {
                        actions?.deselect()
                    }
                }

                ForEach(page.sortedItems, id: \.id) { item in
                    ScrapbookItemView(
                        item: item,
                        photo: item.photoID.flatMap { photos[$0] },
                        photoAspect: photoAspect(item),
                        pageSize: geometry.size,
                        isSelected: selectedItemID == item.id,
                        shouldPlay: { shouldPlay(item, $0) },
                        actions: actions,
                        isHidden: item.id == activeDrawingID,
                        isOverTrash: isTrashTargeted && draggedItemID == item.id,
                        drawingDataOverride: drawingDataOverrides[item.id]
                    )
                }

                if showsDrawingImage {
                    ScrapbookDrawingImage(data: page.drawingData)
                }
            }
            .coordinateSpace(name: Self.coordinateSpace)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(Rectangle().inset(by: draggedItemID != nil ? -2000 : 0))
    }
}
