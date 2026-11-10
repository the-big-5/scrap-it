import CoreGraphics

/// Size and coordinates of a scrapbook item on its page (change 013, POC). Shared by the item view,
/// the scissors and the editor ViewModel so their math matches.
enum ScrapbookItemLayout {
    /// White photo frame, relative to the photo width.
    static let frameInsetRatio: CGFloat = 0.035

    /// Width / height: the sticker's, letter's or washi piece's, a drawing layer's page ratio, else the photo's
    /// (`photoAspect`), else square.
    static func aspectRatio(of item: ScrapbookItem, photoAspect: CGFloat?) -> CGFloat {
        if let sticker = item.sticker { return sticker.aspectRatio }
        if let letter = item.letterID.flatMap(LetterCatalog.letter(withID:)) { return letter.aspectRatio }
        if item.washiID != nil { return max(item.washiLength ?? item.width, 0.01) / WashiCatalog.tapeWidth }
        if item.drawingData != nil { return 3 / 4 }
        guard let photoAspect, photoAspect > 0 else { return 1 }
        return photoAspect
    }

    /// The item's box on the page: photo plus white frame, or other items as they are.
    static func boxSize(of item: ScrapbookItem, photoAspect: CGFloat?, pageSize: CGSize) -> CGSize {
        let range = item.widthRange
        let width = min(max(item.width, range.lowerBound), range.upperBound) * pageSize.width
        let height = width / aspectRatio(of: item, photoAspect: photoAspect)
        guard item.kind == .photo else { return CGSize(width: width, height: height) }
        let inset = width * frameInsetRatio
        return CGSize(width: width + 2 * inset, height: height + 2 * inset)
    }

    /// Page point → normalized point in the item's box (0–1), including position and rotation.
    static func normalizedPoint(_ point: CGPoint, in item: ScrapbookItem, box: CGSize, pageSize: CGSize) -> CGPoint {
        let dx = point.x - item.centerX * pageSize.width
        let dy = point.y - item.centerY * pageSize.height
        let c = cos(-item.rotation), s = sin(-item.rotation)
        let x = dx * c - dy * s
        let y = dx * s + dy * c
        return CGPoint(x: x / box.width + 0.5, y: y / box.height + 0.5)
    }

    /// Inverse of `normalizedPoint`.
    static func pagePoint(_ point: CGPoint, in item: ScrapbookItem, box: CGSize, pageSize: CGSize) -> CGPoint {
        let x = (point.x - 0.5) * box.width
        let y = (point.y - 0.5) * box.height
        let c = cos(item.rotation), s = sin(item.rotation)
        return CGPoint(x: item.centerX * pageSize.width + x * c - y * s,
                       y: item.centerY * pageSize.height + x * s + y * c)
    }

    /// Rotation within ±3° snaps to 0 (POC).
    static func snappedRotation(_ radians: Double) -> Double {
        let rotation = remainder(radians, 2 * .pi)
        return abs(rotation) < 3 * .pi / 180 ? 0 : rotation
    }
}
