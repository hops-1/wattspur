import Foundation

// Heat map (B-108, MAP-04b) and clicking on a route (B-109, MAP-05) on the map of
// all rides. Plain values; the app converts screen points into the sizes here.

/// Web Mercator, as MapKit draws its maps: the whole world is the unit square,
/// x to the east, y to the south. A cell of the heat map is a square in these units.
public struct MercatorPoint: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(_ p: RoutePoint) {
        let lat = min(85.0511, max(-85.0511, p.latitude)) * .pi / 180
        x = (p.longitude + 180) / 360
        y = (1 - log(tan(lat) + 1 / cos(lat)) / .pi) / 2
    }
}

/// The fixed steps of the heat map (Requirements 10.11): different rides per cell.
public enum DensityStep: Int, CaseIterable, Sendable, Comparable {
    case one, few, some, many, most

    public init(count: Int) {
        switch count {
        case ..<2: self = .one
        case 2..<5: self = .few
        case 5..<10: self = .some
        case 10..<20: self = .many
        default: self = .most
        }
    }

    /// For the legend: 1, 2–4, 5–9, 10–19, 20+ (`upperBound` `nil` = open).
    public var range: (lowerBound: Int, upperBound: Int?) {
        switch self {
        case .one: (1, 1)
        case .few: (2, 4)
        case .some: (5, 9)
        case .many: (10, 19)
        case .most: (20, nil)
        }
    }

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Cells of the heat map with the number of different rides that pass through each.
public struct RouteDensity: Sendable {
    public struct Cell: Sendable, Hashable {
        public var column: Int
        public var row: Int
    }

    /// Cell edge in Mercator units; the app takes about 16 pt at the current zoom.
    public let cellSize: Double
    public private(set) var counts: [Cell: Int] = [:]

    /// - Parameter area: only cells in this rectangle are counted, so a close zoom
    ///   does not rasterise every ride of the library.
    public init(rides: [MapRide], cellSize: Double, area: GeoBounds? = nil) {
        self.cellSize = cellSize
        guard cellSize > 0 else { return }
        // North-west and south-east corner: Mercator y grows to the south.
        let visible = area.map { area -> (columns: ClosedRange<Int>, rows: ClosedRange<Int>) in
            let low = cell(of: MercatorPoint(RoutePoint(latitude: area.maxLatitude, longitude: area.minLongitude)))
            let high = cell(of: MercatorPoint(RoutePoint(latitude: area.minLatitude, longitude: area.maxLongitude)))
            return (low.column...high.column, low.row...high.row)
        }
        for ride in rides {
            if let area, !ride.bounds.intersects(area) { continue }
            var cells = Set<Cell>()
            for segment in ride.route.segments {
                let points = segment.map(MercatorPoint.init)
                if points.count == 1 { cells.insert(cell(of: points[0])) }
                for (a, b) in zip(points, points.dropFirst()) {
                    // Steps of half a cell, so a line cannot jump over a cell.
                    let steps = max(1, Int((hypot(b.x - a.x, b.y - a.y) / (cellSize / 2)).rounded(.up)))
                    for i in 0...steps {
                        let t = Double(i) / Double(steps)
                        cells.insert(cell(of: MercatorPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)))
                    }
                }
            }
            if let visible { cells = cells.filter { visible.columns.contains($0.column) && visible.rows.contains($0.row) } }
            // Each ride counts once per cell, even when it passes several times.
            for c in cells { counts[c, default: 0] += 1 }
        }
    }

    /// The cell edge for about `points` screen points at a zoom where one screen
    /// point is `unitsPerPoint` Mercator units, rounded to a power of two, so the
    /// grid only changes from one zoom level to the next, not while zooming a little.
    public static func cellSize(points: Double = 16, unitsPerPoint: Double) -> Double {
        guard unitsPerPoint > 0 else { return 0 }
        return pow(2, (log2(points * unitsPerPoint)).rounded())
    }

    public func cell(of p: MercatorPoint) -> Cell {
        Cell(column: Int((p.x / cellSize).rounded(.down)), row: Int((p.y / cellSize).rounded(.down)))
    }

    /// The cell's corner towards north-west and its edge, in Mercator units.
    public func origin(of c: Cell) -> MercatorPoint {
        MercatorPoint(x: Double(c.column) * cellSize, y: Double(c.row) * cellSize)
    }

    public func step(of c: Cell) -> DensityStep? {
        counts[c].map(DensityStep.init(count:))
    }
}

/// Which rides run past a clicked point (B-109, MAP-05).
public enum RouteHitTest {
    /// Rides whose route passes within `radius` metres of `point`, newest first.
    /// The app converts its 10 pt click radius into metres at the current zoom.
    public static func rides(near point: RoutePoint, radius: Double, in rides: [MapRide]) -> [MapRide] {
        let plane = RouteSimplifier.LocalPlane(origin: point)
        let dLat = radius / plane.metresPerDegreeLatitude
        let dLon = radius / max(1, plane.metresPerDegreeLongitude)
        let around = GeoBounds(minLatitude: point.latitude - dLat, maxLatitude: point.latitude + dLat,
                               minLongitude: point.longitude - dLon, maxLongitude: point.longitude + dLon)
        let p = plane.project(point)
        return rides.filter { ride in
            guard ride.bounds.intersects(around) else { return false }
            for segment in ride.route.segments {
                let projected = segment.map(plane.project)
                if projected.count == 1, hypot(projected[0].x - p.x, projected[0].y - p.y) <= radius { return true }
                for (a, b) in zip(projected, projected.dropFirst())
                where RouteSimplifier.distanceToSegment(p, a, b) <= radius { return true }
            }
            return false
        }
        .sorted { $0.figures.startDate > $1.figures.startDate }
    }
}
