import CoreGraphics

/// Scissors geometry from the camera POC (change 013): simplify the finger path and split a polygon
/// along a free-hand cut. Pure math, no UI, so it is tested on its own.

nonisolated enum CutGeometry {
    static let unitSquare = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)]
    static let minimumPieceArea: CGFloat = 0.02
    static let maxPolygonPoints = 200

    static func simplify(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack = [(0, points.count - 1)]
        while let (start, end) = stack.popLast() {
            var maxDistance: CGFloat = 0
            var index = start
            for i in (start + 1)..<end {
                let distance = perpendicularDistance(points[i], points[start], points[end])
                if distance > maxDistance {
                    maxDistance = distance
                    index = i
                }
            }
            if maxDistance > tolerance {
                keep[index] = true
                stack.append((start, index))
                stack.append((index, end))
            }
        }
        return points.indices.filter { keep[$0] }.map { points[$0] }
    }

    static func splitAll(_ polygon: [CGPoint], by path: [CGPoint], minimumArea: CGFloat,
                         maxPieces: Int = 12) -> [[CGPoint]]? {
        var pieces = [polygon]
        for chord in chords(of: polygon, path: path) {
            var next: [[CGPoint]] = []
            for piece in pieces {
                if pieces.count - 1 + next.count + 2 <= maxPieces,
                   let (first, second) = split(piece, by: chord, minimumArea: minimumArea) {
                    next += [first, second]
                } else {
                    next.append(piece)
                }
            }
            pieces = next
        }
        return pieces.count > 1 ? pieces : nil
    }

    /// A cut with auto-complete (change 126): an edge-to-edge stroke splits as before; otherwise a rough loop inside
    /// the polygon cuts out what it encloses (the rest keeps a hole); otherwise the stroke's ends are continued
    /// straight to the polygon's edge. Only strokes that touch the polygon are completed.
    static func autoCompletedPieces(_ polygon: [CGPoint], by path: [CGPoint], minimumArea: CGFloat,
                                    maxPieces: Int = 12) -> [[CGPoint]]? {
        if let pieces = splitAll(polygon, by: path, minimumArea: minimumArea, maxPieces: maxPieces) {
            return pieces
        }
        guard maxPieces >= 2, path.count >= 2, path.contains(where: { contains(polygon, $0) }) else { return nil }
        if let loop = closedLoop(path, in: polygon),
           let pieces = cutOut(loop, from: polygon, minimumArea: minimumArea) {
            return pieces
        }
        return splitAll(polygon, by: extendedToEdges(path), minimumArea: minimumArea, maxPieces: maxPieces)
    }

    /// The stroke as a closed loop when it's long enough, comes back near its start and stays inside the polygon.
    static func closedLoop(_ path: [CGPoint], in polygon: [CGPoint]) -> [CGPoint]? {
        guard path.count >= 3 else { return nil }
        let length = zip(path, path.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
        let gap = distance(path[0], path[path.count - 1])
        guard length >= 0.3, gap <= min(0.2, length * 0.35),
              path.allSatisfy({ contains(polygon, $0) }) else { return nil }
        return gap < 0.005 ? Array(path.dropLast()) : path
    }

    /// The loop's inside as its own piece, and the polygon with a hole where it was. The hole is joined to the
    /// outline by a zero-width bridge so the result stays one polygon (`ItemMaskShape` draws it as two rings).
    static func cutOut(_ loop: [CGPoint], from polygon: [CGPoint],
                       minimumArea: CGFloat) -> [[CGPoint]]? {
        let inner = limited(loop)
        guard inner.count >= 3, area(inner) >= minimumArea, area(polygon) - area(inner) >= minimumArea else { return nil }
        return [bridged(outer: limited(polygon), hole: inner), inner]
    }

    /// Outer ring … O, H … H, O … ring: the hole runs the other way round, so a nonzero fill leaves it empty.
    static func bridged(outer: [CGPoint], hole: [CGPoint]) -> [CGPoint] {
        var ring = hole
        if (signedArea(ring) > 0) == (signedArea(outer) > 0) { ring.reverse() }
        var best = (outer: 0, hole: 0, distance: CGFloat.infinity)
        for (i, o) in outer.enumerated() {
            for (j, h) in ring.enumerated() where distance(o, h) < best.distance {
                best = (i, j, distance(o, h))
            }
        }
        let rotated = Array(ring[best.hole...] + ring[..<best.hole])
        return Array(outer[...best.outer]) + rotated + [rotated[0]] + Array(outer[best.outer...])
    }

    /// Splits a bridged polygon back into its outer ring and its hole; `nil` when it has no hole.
    static func rings(of polygon: [CGPoint]) -> (outer: [CGPoint], hole: [CGPoint])? {
        for a in polygon.indices where a + 1 < polygon.count {
            for b in (a + 3)..<max(a + 3, polygon.count) where polygon[b] == polygon[a] && polygon[b - 1] == polygon[a + 1] {
                let hole = Array(polygon[(a + 1)...(b - 2)])
                let outer = Array(polygon[...a]) + Array(polygon[(b + 1)...])
                guard hole.count >= 3, outer.count >= 3 else { continue }
                return (outer, hole)
            }
        }
        return nil
    }

    /// Both ends continued straight, in the direction of the stroke's last stretch, well past the polygon.
    static func extendedToEdges(_ path: [CGPoint]) -> [CGPoint] {
        guard path.count >= 2 else { return path }
        func continued(_ end: CGPoint, inward points: [CGPoint]) -> CGPoint {
            let neighbor = points.first { distance($0, end) >= 0.05 } ?? points[0]
            return extend(end, awayFrom: neighbor, by: 3)
        }
        let start = continued(path[0], inward: Array(path.dropFirst()))
        let end = continued(path[path.count - 1], inward: Array(path.dropLast().reversed()))
        return [start] + path + [end]
    }

    private static func signedArea(_ polygon: [CGPoint]) -> CGFloat {
        guard polygon.count >= 3 else { return 0 }
        var sum: CGFloat = 0
        for i in polygon.indices {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }

    static func split(_ polygon: [CGPoint], by path: [CGPoint],
                      minimumArea: CGFloat = 0) -> (first: [CGPoint], second: [CGPoint])? {
        guard polygon.count >= 3, path.count >= 2 else { return nil }
        for (entry, exit) in crossingPairs(of: polygon, path: path) {
            if let pieces = pieces(of: polygon, path: path, entry: entry, exit: exit),
               area(pieces.first) >= minimumArea, area(pieces.second) >= minimumArea,
               area(pieces.first) > 1e-6, area(pieces.second) > 1e-6 {
                return pieces
            }
        }
        return nil
    }

    static func chords(of polygon: [CGPoint], path: [CGPoint]) -> [[CGPoint]] {
        guard polygon.count >= 3, path.count >= 2 else { return [] }
        return crossingPairs(of: polygon, path: path).compactMap { entry, exit in
            guard distance(entry.point, exit.point) > 0.001 else { return nil }
            let inner = entry.pathSegment < exit.pathSegment
                ? Array(path[(entry.pathSegment + 1)...exit.pathSegment])
                : []
            var chord = [entry.point] + inner + [exit.point]
            chord[0] = extend(chord[0], awayFrom: chord[1])
            chord[chord.count - 1] = extend(chord[chord.count - 1], awayFrom: chord[chord.count - 2])
            return chord
        }
    }

    private static func crossingPairs(of polygon: [CGPoint], path: [CGPoint]) -> [(Crossing, Crossing)] {
        var crossings: [Crossing] = []
        for s in 0..<(path.count - 1) {
            var onSegment: [Crossing] = []
            for e in polygon.indices {
                let a = polygon[e], b = polygon[(e + 1) % polygon.count]
                if let (t, u) = intersection(path[s], path[s + 1], a, b) {
                    onSegment.append(Crossing(point: point(path[s], path[s + 1], t),
                                              pathSegment: s, pathT: t, edge: e, edgeT: u))
                }
            }
            crossings += onSegment.sorted { $0.pathT < $1.pathT }
        }

        var pairs: [(Crossing, Crossing)] = []
        var inside = contains(polygon, path[0])
        var entry: Crossing?
        for crossing in crossings {
            if !inside {
                entry = crossing
            } else if let currentEntry = entry {
                pairs.append((currentEntry, crossing))
                entry = nil
            }
            inside.toggle()
        }
        return pairs
    }

    private static func extend(_ end: CGPoint, awayFrom neighbor: CGPoint, by amount: CGFloat = 0.01) -> CGPoint {
        let length = distance(end, neighbor)
        guard length > 0 else { return end }
        return CGPoint(x: end.x + (end.x - neighbor.x) / length * amount,
                       y: end.y + (end.y - neighbor.y) / length * amount)
    }

    private struct Crossing {
        let point: CGPoint
        let pathSegment: Int
        let pathT: CGFloat
        let edge: Int
        let edgeT: CGFloat
    }

    private static func pieces(of polygon: [CGPoint], path: [CGPoint], entry: Crossing,
                               exit: Crossing) -> (first: [CGPoint], second: [CGPoint])? {
        guard distance(entry.point, exit.point) > 0.001 else { return nil }

        let inner = entry.pathSegment < exit.pathSegment
            ? Array(path[(entry.pathSegment + 1)...exit.pathSegment])
            : []

        func vertices(after from: Crossing, until to: Crossing) -> [CGPoint] {
            let n = polygon.count
            if from.edge == to.edge {
                if to.edgeT >= from.edgeT { return [] }
                return (1...n).map { polygon[(from.edge + $0) % n] }
            }
            var result: [CGPoint] = []
            var index = (from.edge + 1) % n
            while true {
                result.append(polygon[index])
                if index == to.edge { break }
                index = (index + 1) % n
            }
            return result
        }

        let first = [exit.point] + vertices(after: exit, until: entry) + [entry.point] + inner
        let second = [entry.point] + vertices(after: entry, until: exit) + [exit.point] + inner.reversed()
        return (limited(first), limited(second))
    }

    static func area(_ polygon: [CGPoint]) -> CGFloat {
        guard polygon.count >= 3 else { return 0 }
        var sum: CGFloat = 0
        for i in polygon.indices {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    static func centroid(_ polygon: [CGPoint]) -> CGPoint {
        let count = CGFloat(max(polygon.count, 1))
        return CGPoint(x: polygon.reduce(0) { $0 + $1.x } / count, y: polygon.reduce(0) { $0 + $1.y } / count)
    }

    static func contains(_ polygon: [CGPoint], _ p: CGPoint) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i], b = polygon[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    private static func limited(_ polygon: [CGPoint]) -> [CGPoint] {
        var result = polygon
        var tolerance: CGFloat = 0.002
        while result.count > maxPolygonPoints {
            result = Array(simplify(result + [result[0]], tolerance: tolerance).dropLast())
            tolerance *= 2
        }
        return result
    }

    private static func intersection(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> (CGFloat, CGFloat)? {
        let d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
        guard abs(d) > 1e-12 else { return nil }
        let t = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
        let u = ((p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)) / d
        guard t >= 0, t <= 1, u >= 0, u < 1 else { return nil }
        return (t, u)
    }

    private static func point(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private static func perpendicularDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let length = distance(a, b)
        guard length > 0 else { return distance(p, a) }
        return abs((b.x - a.x) * (a.y - p.y) - (a.x - p.x) * (b.y - a.y)) / length
    }
}
