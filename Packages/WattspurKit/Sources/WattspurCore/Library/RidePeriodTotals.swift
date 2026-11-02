import Foundation

/// The two totals of the iPhone overview (B-205, later B-214): the distance ridden in the calendar
/// week of `now` and the number of rides in its calendar month. Weeks follow the calendar, so
/// they start on Monday in Germany and on Sunday in the US.
public struct RidePeriodTotals: Sendable, Equatable {
    /// Metres.
    public var weekDistance: Double
    public var weekRides: Int
    /// Metres.
    public var monthDistance: Double
    public var monthRides: Int

    public init(weekDistance: Double = 0, weekRides: Int = 0, monthDistance: Double = 0, monthRides: Int = 0) {
        self.weekDistance = weekDistance
        self.weekRides = weekRides
        self.monthDistance = monthDistance
        self.monthRides = monthRides
    }

    /// Sums the rides that start in the week and in the month of `now`. A ride counts where it
    /// starts, even if it goes on past midnight into the next week.
    public init(rides: some Sequence<(start: Date, distance: Double)>, now: Date = .now,
                calendar: Calendar = .current) {
        self.init()
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let month = calendar.dateInterval(of: .month, for: now)
        for ride in rides {
            if let week, week.start <= ride.start, ride.start < week.end {
                weekDistance += ride.distance
                weekRides += 1
            }
            if let month, month.start <= ride.start, ride.start < month.end {
                monthDistance += ride.distance
                monthRides += 1
            }
        }
    }
}
