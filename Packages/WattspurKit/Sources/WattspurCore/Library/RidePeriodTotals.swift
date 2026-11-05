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
    /// Metres; the year tile of the landscape overview (B-243).
    public var yearDistance: Double
    public var yearRides: Int

    public init(weekDistance: Double = 0, weekRides: Int = 0, monthDistance: Double = 0, monthRides: Int = 0,
                yearDistance: Double = 0, yearRides: Int = 0) {
        self.weekDistance = weekDistance
        self.weekRides = weekRides
        self.monthDistance = monthDistance
        self.monthRides = monthRides
        self.yearDistance = yearDistance
        self.yearRides = yearRides
    }

    /// Sums the rides that start in the week, the month and the year of `now`. A ride counts where it
    /// starts, even if it goes on past midnight into the next week.
    public init(rides: some Sequence<(start: Date, distance: Double)>, now: Date = .now,
                calendar: Calendar = .current) {
        self.init()
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let month = calendar.dateInterval(of: .month, for: now)
        let year = calendar.dateInterval(of: .year, for: now)
        for ride in rides {
            if let week, week.start <= ride.start, ride.start < week.end {
                weekDistance += ride.distance
                weekRides += 1
            }
            if let month, month.start <= ride.start, ride.start < month.end {
                monthDistance += ride.distance
                monthRides += 1
            }
            if let year, year.start <= ride.start, ride.start < year.end {
                yearDistance += ride.distance
                yearRides += 1
            }
        }
    }
}
