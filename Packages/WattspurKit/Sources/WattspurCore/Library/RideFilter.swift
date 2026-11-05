import Foundation

/// Search and filters of a ride list (B-222, LIST-05): the name, the bike, a period and the
/// distance. One rule for the iPhone and, with B-244, the Mac, so both find the same rides.
public struct RideFilter: Sendable, Equatable, Hashable {
    /// Part of the name; empty finds every ride. Case and accents do not matter.
    public var text: String
    public var bike: BikeFilter
    public var period: RidePeriod
    public var distance: RideDistanceBand

    public init(text: String = "", bike: BikeFilter = .all, period: RidePeriod = .all,
                distance: RideDistanceBand = .all) {
        self.text = text
        self.bike = bike
        self.period = period
        self.distance = distance
    }

    /// Whether any filter or search narrows the list.
    public var isActive: Bool { !trimmedText.isEmpty || bike.isActive || period != .all || distance != .all }

    /// Whether a filter other than the search is set; the filter button shows it filled.
    public var hasFilters: Bool { bike.isActive || period != .all || distance != .all }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Whether a ride with these values passes. `distance` in metres.
    public func admits(name: String, startDate: Date, bikeID: UUID?, distance metres: Double,
                       now: Date = .now, calendar: Calendar = .current) -> Bool {
        let search = trimmedText
        if !search.isEmpty, !name.localizedStandardContains(search) { return false }
        guard bike.admits(bikeID: bikeID) else { return false }
        guard period.contains(startDate, now: now, calendar: calendar) else { return false }
        return distance.contains(metres)
    }

    public func admits(_ ride: RideExchange.Ride, now: Date = .now, calendar: Calendar = .current) -> Bool {
        admits(name: ride.name, startDate: ride.startDate, bikeID: ride.bikeID, distance: ride.distance,
               now: now, calendar: calendar)
    }

    /// The same filter, with a bike that is gone or a bike filter without a second bike as “all”
    /// (`BikeFilter.resolved`), so a hidden choice does not keep working unseen.
    public func resolved(knownBikeIDs: Set<UUID>) -> RideFilter {
        var filter = self
        filter.bike = bike.resolved(knownBikeIDs: knownBikeIDs)
        return filter
    }
}

/// Distance ranges to filter by (B-222): short rides, the usual commute, longer tours.
/// A ride counts in the band where its distance lies; the upper bound is not included.
public enum RideDistanceBand: String, CaseIterable, Identifiable, Sendable {
    case all
    case under10
    case from10To25
    case from25To50
    case over50

    public var id: Self { self }

    /// Metres; `nil` means no limit on that side.
    public var range: (lower: Double?, upper: Double?) {
        switch self {
        case .all: (nil, nil)
        case .under10: (nil, 10_000)
        case .from10To25: (10_000, 25_000)
        case .from25To50: (25_000, 50_000)
        case .over50: (50_000, nil)
        }
    }

    public func contains(_ metres: Double) -> Bool {
        let (lower, upper) = range
        if let lower, metres < lower { return false }
        if let upper, metres >= upper { return false }
        return true
    }
}

extension RideExchange.Library {
    /// The rides that pass the filter, by month as in `months()`.
    public func months(filteredBy filter: RideFilter, now: Date = .now, calendar: Calendar = .current) -> [Month] {
        guard filter.isActive else { return months(calendar: calendar) }
        var library = self
        library.rides = rides.filter { filter.admits($0, now: now, calendar: calendar) }
        return library.months(calendar: calendar)
    }
}
