import Foundation

/// "New paths" (B-115, part of IDEA-12): how much of a ride ran where no earlier
/// ride had been. Measured on a fixed grid of 50 m cells (Requirements 10.11).
public enum NewPaths {
    /// A ride as the grid sees it. Parts of a merged ride come one by one, each
    /// with its own start; the app adds up a merged ride from its parts.
    public struct Input: Sendable {
        public var id: UUID
        public var startDate: Date
        public var route: OverviewRoute

        public init(id: UUID, startDate: Date, route: OverviewRoute) {
            self.id = id
            self.startDate = startDate
            self.route = route
        }
    }

    public struct Result: Sendable, Equatable {
        /// Length of the overview route in metres.
        public var routeLength: Double
        /// Metres of it on new paths.
        public var newLength: Double
        /// The new stretches, to draw them stronger on the ride's map.
        public var stretches: [[RoutePoint]]

        public init(routeLength: Double, newLength: Double, stretches: [[RoutePoint]]) {
            self.routeLength = routeLength
            self.newLength = newLength
            self.stretches = stretches
        }

        /// 0…1; 0 for a route without length.
        public var share: Double { routeLength > 0 ? min(1, newLength / routeLength) : 0 }
    }

    public static let cellSize = 50.0
    /// A point closer than this to a ridden cell counts as known, so GPS noise
    /// along a road on a cell border does not make the same road look new.
    public static let slack = 10.0
    /// Distance between the points checked along the route.
    static let step = 10.0

    /// Goes through the rides from the oldest to the newest; each ride's cells
    /// become known only after the ride, so riding out and back on a new road
    /// counts both ways as new.
    public static func compute(_ rides: [Input]) -> [UUID: Result] {
        var known = Set<Cell>()
        var results: [UUID: Result] = [:]
        for ride in rides.sorted(by: { $0.startDate < $1.startDate }) {
            var ridden = Set<Cell>()
            var result = Result(routeLength: 0, newLength: 0, stretches: [])
            for segment in ride.route.segments {
                var stretch: [RoutePoint] = []
                func closeStretch() {
                    if stretch.count > 1 { result.stretches.append(stretch) }
                    stretch = []
                }
                for (a, b) in zip(segment, segment.dropFirst()) {
                    let length = distance(a, b)
                    result.routeLength += length
                    let steps = max(1, Int((length / step).rounded(.up)))
                    for i in 0..<steps {
                        let from = interpolate(a, b, Double(i) / Double(steps))
                        let to = interpolate(a, b, Double(i + 1) / Double(steps))
                        let middle = interpolate(a, b, (Double(i) + 0.5) / Double(steps))
                        ridden.insert(cell(of: middle))
                        if isKnown(middle, in: known) {
                            closeStretch()
                        } else {
                            result.newLength += length / Double(steps)
                            if stretch.isEmpty { stretch.append(from) }
                            stretch.append(to)
                        }
                    }
                }
                closeStretch()
            }
            known.formUnion(ridden)
            results[ride.id] = result
        }
        return results
    }

    // MARK: - Grid

    struct Cell: Hashable {
        var row: Int
        var column: Int
    }

    private static let metresPerDegree = RouteSimplifier.LocalPlane.earthRadius * .pi / 180

    /// Rows are 50 m high everywhere; within a row the cells are 50 m wide at
    /// the row's middle latitude, so the grid is the same for every ride.
    static func cell(of p: RoutePoint) -> Cell {
        let rowHeight = cellSize / metresPerDegree
        let row = Int((p.latitude / rowHeight).rounded(.down))
        let middle = (Double(row) + 0.5) * rowHeight * .pi / 180
        let columnWidth = cellSize / (metresPerDegree * max(0.01, cos(middle)))
        return Cell(row: row, column: Int((p.longitude / columnWidth).rounded(.down)))
    }

    private static func isKnown(_ p: RoutePoint, in known: Set<Cell>) -> Bool {
        guard !known.isEmpty else { return false }
        let dLat = slack / metresPerDegree
        let dLon = slack / (metresPerDegree * max(0.01, cos(p.latitude * .pi / 180)))
        return [(0.0, 0.0), (dLat, 0), (-dLat, 0), (0, dLon), (0, -dLon)].contains { offset in
            known.contains(cell(of: RoutePoint(latitude: p.latitude + offset.0, longitude: p.longitude + offset.1)))
        }
    }

    private static func distance(_ a: RoutePoint, _ b: RoutePoint) -> Double {
        let plane = RouteSimplifier.LocalPlane(origin: a)
        let p = plane.project(b)
        return hypot(p.x, p.y)
    }

    private static func interpolate(_ a: RoutePoint, _ b: RoutePoint, _ t: Double) -> RoutePoint {
        RoutePoint(latitude: a.latitude + (b.latitude - a.latitude) * t,
                   longitude: a.longitude + (b.longitude - a.longitude) * t)
    }
}

extension Ride {
    /// The rides "new paths" are measured against: everything that counts, with a
    /// merged ride's parts in its place (each with its own start), without the
    /// sample ride and the trash.
    @MainActor
    public static func newPathInputs(_ rides: [Ride]) -> [NewPaths.Input] {
        rides.filter { $0.deletedAt == nil && !$0.isSample && !$0.isMerged && ($0.mergedInto?.deletedAt == nil) }
            .compactMap { ride in ride.overviewRoute.map { NewPaths.Input(id: ride.id, startDate: ride.startDate, route: $0) } }
    }
}
