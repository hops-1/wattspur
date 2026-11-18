import Foundation

/// The sport menu on the iPhone (B-289): Overview, Rides and Map show one sport at a time.
extension RideExchange.Library {
    /// The sports there are: open devices and listed rides (`SportChoice.available`).
    public var availableSports: [Sport] {
        SportChoice.available(deviceKinds: bikes.filter { !$0.isArchived }.map(\.kind),
                              rideSports: rides.map { sport(of: $0) })
    }

    /// The same library with only the rides of one sport; the devices stay, for names and symbols.
    public func only(_ sport: Sport) -> RideExchange.Library {
        var library = self
        library.rides = rides.filter { self.sport(of: $0) == sport }
        return library
    }

    /// The devices of a sport, archived ones included.
    public func devices(of sport: Sport) -> [RideExchange.Bike] {
        bikes.filter { (BikeKind(rawValue: $0.kind) ?? .bike).sport == sport }
    }

    /// The tiles “This Week” and “This Month” of one sport.
    public func totals(of sport: Sport, now: Date = .now, calendar: Calendar = .current) -> RidePeriodTotals {
        RidePeriodTotals(rides: only(sport).rides.map { (start: $0.startDate, distance: $0.distance) }, now: now, calendar: calendar)
    }
}

extension RideExchange.Library {
    /// The sport shown for a stored choice: the choice while there is that sport, else the first one.
    public func shownSport(_ stored: Sport) -> Sport {
        SportChoice.resolved(stored, available: availableSports)
    }
}
