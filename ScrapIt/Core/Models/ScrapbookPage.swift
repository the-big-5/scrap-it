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
    /// `nil` = a page of the book; `Role.rawValue` = the front cover or the spine (change 026).
    var role: String?

    enum Role: String {
        case front, spine

        /// Width / height of the cover side (Figma 340 × 468 front, 74 × 462 spine).
        var aspectRatio: CGFloat {
            switch self {
            case .front: 340 / 468
            case .spine: 74 / 462
            }
        }
    }

    /// Fixed coordinate space for drawings, scaled to the page's size on screen.
    nonisolated static let canvasSize = CGSize(width: 600, height: 800)

    /// The drawing space for a page of any shape: 800 high, width by the page's ratio (600 for a 3:4 page; the front
    /// cover and the narrow spine, change 026). Height-based so strokes keep their size on the spine.
    nonisolated static func canvasSize(for pageSize: CGSize) -> CGSize {
        guard pageSize.height > 0 else { return canvasSize }
        return CGSize(width: canvasSize.height * pageSize.width / pageSize.height, height: canvasSize.height)
    }

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
