import Foundation

// The map of all rides (v1.4: AGG-05, AGG-06; B-106, B-114). Plain values, so the
// filter and the totals of the visible area are testable without SwiftData or MapKit.

/// A rectangle in degrees. The map of all rides stays far from the 180th
/// meridian, so longitudes simply run from west to east.
public struct GeoBounds: Sendable, Equatable {
    public var minLatitude: Double
    public var maxLatitude: Double
    public var minLongitude: Double
    public var maxLongitude: Double

    public init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }

    /// The smallest rectangle around the points; `nil` without points.
    public init?<S: Sequence>(_ points: S) where S.Element == RoutePoint {
        var iterator = points.makeIterator()
        guard let first = iterator.next() else { return nil }
        self.init(minLatitude: first.latitude, maxLatitude: first.latitude,
                  minLongitude: first.longitude, maxLongitude: first.longitude)
        while let p = iterator.next() {
            minLatitude = min(minLatitude, p.latitude)
            maxLatitude = max(maxLatitude, p.latitude)
            minLongitude = min(minLongitude, p.longitude)
            maxLongitude = max(maxLongitude, p.longitude)
        }
    }

    public func contains(_ p: RoutePoint) -> Bool {
        (minLatitude...maxLatitude).contains(p.latitude) && (minLongitude...maxLongitude).contains(p.longitude)
    }

    public func intersects(_ other: GeoBounds) -> Bool {
        minLatitude <= other.maxLatitude && other.minLatitude <= maxLatitude
            && minLongitude <= other.maxLongitude && other.minLongitude <= maxLongitude
    }

    public func union(_ other: GeoBounds) -> GeoBounds {
        GeoBounds(minLatitude: min(minLatitude, other.minLatitude), maxLatitude: max(maxLatitude, other.maxLatitude),
                  minLongitude: min(minLongitude, other.minLongitude), maxLongitude: max(maxLongitude, other.maxLongitude))
    }

    /// Whether the straight line from `a` to `b` runs through the rectangle, also
    /// when neither end lies inside: after simplifying, a straight road can be a
    /// single line several kilometres long (Liang–Barsky clipping).
    public func intersects(from a: RoutePoint, to b: RoutePoint) -> Bool {
        if contains(a) || contains(b) { return true }
        let dx = b.longitude - a.longitude, dy = b.latitude - a.latitude
        var t0 = 0.0, t1 = 1.0
        let edges = [(-dx, a.longitude - minLongitude), (dx, maxLongitude - a.longitude),
                     (-dy, a.latitude - minLatitude), (dy, maxLatitude - a.latitude)]
        for (p, q) in edges {
            if p == 0 {
                if q < 0 { return false }
            } else {
                let r = q / p
                if p < 0 { t0 = max(t0, r) } else { t1 = min(t1, r) }
                if t0 > t1 { return false }
            }
        }
        return true
    }
}

/// One ride on the map: its figures for the totals and its overview route.
public struct MapRide: Sendable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var figures: RideFigures
    public var route: OverviewRoute
    public let bounds: GeoBounds

    /// `nil` for a ride without GPS.
    public init?(id: UUID, name: String, figures: RideFigures, route: OverviewRoute) {
        guard let bounds = GeoBounds(route.segments.joined()) else { return nil }
        self.id = id
        self.name = name
        self.figures = figures
        self.route = route
        self.bounds = bounds
    }

    /// Whether any part of the route runs through the rectangle.
    public func touches(_ area: GeoBounds) -> Bool {
        guard bounds.intersects(area) else { return false }
        for segment in route.segments {
            if segment.count == 1, area.contains(segment[0]) { return true }
            for (a, b) in zip(segment, segment.dropFirst()) where area.intersects(from: a, to: b) { return true }
        }
        return false
    }
}

/// Which rides the map shows (AGG-05, Requirements 10.11).
public struct MapFilter: Sendable, Equatable {
    /// `nil` shows all periods.
    public var interval: DateInterval?
    /// The rides selected in the list, when the map shows only those; `nil` otherwise.
    /// Then the period does not apply, and the sample ride may be among them.
    public var selectedIDs: Set<UUID>?
    /// Only the rides of this bike (B-137, B-110). Does not apply to `selectedIDs`:
    /// rides picked by hand are shown whatever bike they are on.
    public var bike: BikeFilter
    /// Only the rides from this kind of file (B-145). Like the bike, it does not apply to `selectedIDs`.
    public var source: SourceFilter

    public init(interval: DateInterval? = nil, selectedIDs: Set<UUID>? = nil, bike: BikeFilter = .all, source: SourceFilter = .all) {
        self.interval = interval
        self.selectedIDs = selectedIDs
        self.bike = bike
        self.source = source
    }

    /// - Parameters:
    ///   - countsInStatistics: not in the trash, not the sample ride, not a part of a merged ride.
    ///   - isListed: shown in the ride list, i.e. not in the trash and not a part.
    ///   - bikeID: the ride's bike.
    ///   - rideSource: the kind of file the ride comes from.
    public func admits(id: UUID, startDate: Date, countsInStatistics: Bool, isListed: Bool, bikeID: UUID? = nil,
                       rideSource: RideSource? = nil) -> Bool {
        if let selectedIDs { return isListed && selectedIDs.contains(id) }
        guard countsInStatistics, bike.admits(bikeID: bikeID), source.admits(source: rideSource) else { return false }
        return interval?.contains(startDate) ?? true
    }
}

extension Ride {
    public func isOnMap(_ filter: MapFilter) -> Bool {
        filter.admits(id: id, startDate: startDate, countsInStatistics: countsInStatistics,
                      isListed: deletedAt == nil && mergedInto == nil, bikeID: bike?.id, rideSource: self.source)
    }

    /// The ride for the map; `nil` without GPS or while its route is still being prepared.
    public var mapRide: MapRide? {
        overviewRoute.flatMap { MapRide(id: id, name: name, figures: figures, route: $0) }
    }
}

/// What the map shows for a filter: the rides with a route, and how many rides
/// it cannot show (B-106).
public struct MapOverview: Sendable {
    /// Newest first.
    public var rides: [MapRide]
    /// Filtered rides without GPS, named in the subtitle.
    public var withoutGPS: Int
    /// Filtered rides whose route is still being prepared (B-104).
    public var preparing: Int
    /// Around all routes, for "show all rides"; `nil` without rides.
    public let bounds: GeoBounds?

    public init(rides: [MapRide], withoutGPS: Int = 0, preparing: Int = 0) {
        self.rides = rides.sorted { $0.figures.startDate > $1.figures.startDate }
        self.withoutGPS = withoutGPS
        self.preparing = preparing
        bounds = rides.dropFirst().reduce(rides.first?.bounds) { $0?.union($1.bounds) }
    }

    /// Collects the filtered rides of the library.
    @MainActor
    public init(_ rides: [Ride], filter: MapFilter) {
        var shown: [MapRide] = [], withoutGPS = 0, preparing = 0
        for ride in rides where ride.isOnMap(filter) {
            if ride.needsOverviewRoute {
                preparing += 1
            } else if let mapRide = ride.mapRide {
                shown.append(mapRide)
            } else {
                withoutGPS += 1
            }
        }
        self.init(rides: shown, withoutGPS: withoutGPS, preparing: preparing)
    }

    /// Totals of all shown rides, for the subtitle.
    public var totals: RideAggregate { RideAggregate(rides.map(\.figures)) }

    /// Rides whose route runs through the visible area: whole rides with their
    /// Bosch totals, not only the visible stretch (AGG-06, B-114).
    public func rides(touching area: GeoBounds) -> [MapRide] {
        rides.filter { $0.touches(area) }
    }

    /// The tiles below the map: sums and time-weighted averages as in the analysis.
    public func aggregate(touching area: GeoBounds) -> RideAggregate {
        RideAggregate(rides(touching: area).map(\.figures))
    }
}
