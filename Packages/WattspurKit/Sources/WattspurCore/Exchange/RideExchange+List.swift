import Foundation

/// What the iPhone shows of a state from the Mac (B-209, B-214).
extension RideExchange.Library {
    /// The rides of one calendar month, newest first.
    public struct Month: Sendable, Equatable, Identifiable {
        /// The first moment of the month.
        public var start: Date
        public var rides: [RideExchange.Ride]

        public var id: Date { start }
    }

    /// The rides by the calendar month of their start, newest month first.
    public func months(calendar: Calendar = .current) -> [Month] {
        var months: [Date: [RideExchange.Ride]] = [:]
        for ride in rides {
            guard let start = calendar.dateInterval(of: .month, for: ride.startDate)?.start else { continue }
            months[start, default: []].append(ride)
        }
        return months.map { Month(start: $0.key, rides: $0.value.sorted { $0.startDate > $1.startDate }) }
            .sorted { $0.start > $1.start }
    }

    /// The ride that started last.
    public var lastRide: RideExchange.Ride? { rides.max { $0.startDate < $1.startDate } }

    public func bike(withID id: UUID?) -> RideExchange.Bike? {
        guard let id else { return nil }
        return bikes.first { $0.id == id }
    }

    /// The bikes to choose from when editing a ride (B-240): those not archived, plus the ride's own
    /// bike even if it is archived, so the picker always shows the current choice.
    public func bikesForEditing(current id: UUID?) -> [RideExchange.Bike] {
        bikes.filter { !$0.isArchived || $0.id == id }
    }

    /// The tiles “This Week” and “This Month”, without motorcycle rides (`BikeKind.isMotorized`).
    public func totals(now: Date = .now, calendar: Calendar = .current) -> RidePeriodTotals {
        RidePeriodTotals(rides: countedRides.map { (start: $0.startDate, distance: $0.distance) }, now: now, calendar: calendar)
    }

    /// The rides that count towards totals: all but those on a motorcycle.
    public var countedRides: [RideExchange.Ride] {
        rides.filter { !isMotorized(bikeID: $0.bikeID) }
    }

    /// Whether the bike with this id is a motorcycle (`BikeKind.isMotorized`).
    public func isMotorized(bikeID: UUID?) -> Bool {
        guard let kind = bike(withID: bikeID)?.kind else { return false }
        return BikeKind(rawValue: kind)?.isMotorized == true
    }
}
