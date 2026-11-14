import PencilKit

/// Picking and changing one drawing inside a page's pencil layer (change 150). Pure math on `PKDrawing`, in the
/// layer's drawing space (`ScrapbookPage.canvasSize`, 800 units high), so it's tested on its own.
nonisolated enum DrawingSelectionGeometry {
    /// Strokes this close (or overlapping) belong to the same drawing: 8 pt at the two-page view's page
    /// (201 pt wide = 600 units). Tune on device.
    static let clusterGap: CGFloat = 24

    /// The topmost stroke passing within `tolerance` of the point, if any.
    static func strokeIndex(at point: CGPoint, in drawing: PKDrawing, tolerance: CGFloat) -> Int? {
        for index in drawing.strokes.indices.reversed() {
            let stroke = drawing.strokes[index]
            guard stroke.renderBounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point) else { continue }
            for sample in stroke.path.interpolatedPoints(by: .distance(2)) {
                let location = sample.location.applying(stroke.transform)
                let reach = tolerance + max(sample.size.width, sample.size.height) / 2
                if hypot(location.x - point.x, location.y - point.y) <= reach {
                    return index
                }
            }
        }
        return nil
    }

    /// The stroke and every stroke overlapping it or within `gap`, and so on through their neighbors, in order.
    static func cluster(from index: Int, in drawing: PKDrawing, gap: CGFloat = clusterGap) -> [Int] {
        let boxes = drawing.strokes.map { $0.renderBounds.insetBy(dx: -gap / 2, dy: -gap / 2) }
        var picked: Set<Int> = [index]
        var queue = [index]
        while let current = queue.popLast() {
            for other in boxes.indices where !picked.contains(other) && boxes[other].intersects(boxes[current]) {
                picked.insert(other)
                queue.append(other)
            }
        }
        return picked.sorted()
    }

    static func bounds(of indices: [Int], in drawing: PKDrawing) -> CGRect {
        indices.reduce(CGRect.null) { $0.union(drawing.strokes[$1].renderBounds) }
    }

    /// Only the given strokes.
    static func strokes(_ indices: [Int], of drawing: PKDrawing) -> PKDrawing {
        PKDrawing(strokes: indices.map { drawing.strokes[$0] })
    }

    /// Every stroke but the given ones.
    static func removing(_ indices: [Int], from drawing: PKDrawing) -> PKDrawing {
        let removed = Set(indices)
        return PKDrawing(strokes: drawing.strokes.indices.filter { !removed.contains($0) }.map { drawing.strokes[$0] })
    }

    /// The given strokes moved by `transform` (after their own transforms); the others untouched.
    static func applying(_ transform: CGAffineTransform, to indices: [Int], in drawing: PKDrawing) -> PKDrawing {
        let changed = Set(indices)
        return PKDrawing(strokes: drawing.strokes.enumerated().map { index, stroke in
            guard changed.contains(index) else { return stroke }
            var moved = stroke
            moved.transform = stroke.transform.concatenating(transform)
            return moved
        })
    }

    /// Scale and rotate around `center`, then move by `translation`.
    static func transform(translation: CGSize, scale: CGFloat, rotation: CGFloat, around center: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -center.x, y: -center.y)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(rotationAngle: rotation))
            .concatenating(CGAffineTransform(translationX: center.x + translation.width, y: center.y + translation.height))
    }
}
