import Foundation

/// A ride's route as a small drawing for the ride list (B-064, LIST-02): the
/// overview route fitted into a unit square, without map tiles.
public struct RoutePreview: Sendable, Equatable {
    /// A point in the unit square: x to the right, y downwards, both 0…1.
    public struct Point: Sendable, Equatable {
        public var x: Double
        public var y: Double
    }

    /// One line per segment, so a merged ride shows one stroke per part.
    public var segments: [[Point]]
    /// Start and finish less than 100 m apart, as in the ride detail.
    public var isLoop: Bool

    public var start: Point? { segments.first?.first }

    /// `nil` for a ride without GPS. `detail` is the share of the larger side the
    /// drawing may deviate, so a 44 pt thumbnail needs only a few dozen points.
    public init?(route: OverviewRoute, detail: Double = 1.0 / 150) {
        let all = route.segments.joined()
        guard let first = all.first, let last = route.segments.last?.last else { return nil }
        let latitudes = all.map(\.latitude)
        let plane = RouteSimplifier.LocalPlane(origin: RoutePoint(
            latitude: ((latitudes.min() ?? 0) + (latitudes.max() ?? 0)) / 2, longitude: first.longitude))
        let projected = route.segments.map { $0.map(plane.project) }
        let xs = projected.joined().map(\.x), ys = projected.joined().map(\.y)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0, minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        let side = max(maxX - minX, maxY - minY)

        // Keep the proportions and centre the shorter side; north is up.
        let place: ((x: Double, y: Double)) -> Point = { p in
            guard side > 0 else { return Point(x: 0.5, y: 0.5) }
            return Point(x: (p.x - minX + (side - (maxX - minX)) / 2) / side,
                         y: 1 - (p.y - minY + (side - (maxY - minY)) / 2) / side)
        }
        let tolerance = side * detail
        segments = zip(route.segments, projected).map { original, points in
            let kept = RouteSimplifier.simplify(original, tolerance: tolerance)
            // Simplifying again only drops points, so map the kept ones back to theirs.
            var index = 0
            return kept.map { point in
                while original[index] != point { index += 1 }
                return place(points[index])
            }
        }
        let a = plane.project(first), b = plane.project(last)
        isLoop = hypot(a.x - b.x, a.y - b.y) < 100
    }
}
