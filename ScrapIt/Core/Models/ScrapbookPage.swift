import CoreGraphics
import Foundation
import SwiftData

/// One 3:4 page of a scrapbook (change 013, ported from the camera POC). Local store only.
@Model
final class ScrapbookPage {
    /// Letters and washi pieces use up the slots quickly (change 022).
    static let maxItems = 40

    var id: UUID = UUID()
    var order: Int = 0
    /// `PageBackground.rawValue`.
    var background: String = PageBackground.cream.rawValue
    /// PencilKit drawing (`PKDrawing.dataRepresentation()`) in `ScrapbookPage.canvasSize` points. Since change 022
    /// drawings are layer items; the editor moves this into a back layer when the page is opened.
    @Attribute(.externalStorage) var drawingData: Data?
    @Relationship(deleteRule: .cascade, inverse: \ScrapbookItem.page)
    var items: [ScrapbookItem]? = []
    var scrapbook: Scrapbook?

    /// Fixed coordinate space for drawings, scaled to the page's size on screen.
    nonisolated static let canvasSize = CGSize(width: 600, height: 800)

    init(order: Int, background: PageBackground = .cream) {
        self.order = order
        self.background = background.rawValue
    }

    var pageBackground: PageBackground {
        PageBackground(rawValue: background) ?? .cream
    }

    var allItems: [ScrapbookItem] { items ?? [] }

    /// Back to front.
    var sortedItems: [ScrapbookItem] {
        allItems.sorted { $0.zIndex < $1.zIndex }
    }

    var maxZIndex: Int { allItems.map(\.zIndex).max() ?? 0 }
    var minZIndex: Int { allItems.map(\.zIndex).min() ?? 0 }
}
