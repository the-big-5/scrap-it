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
