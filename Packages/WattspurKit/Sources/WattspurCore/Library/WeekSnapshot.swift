import Foundation

/// What the iPhone widget “This Week” shows (B-224): the rides of the current week and the last
/// ride. The app writes it into the shared App Group whenever its rides change; the widget reads it
/// and does the week itself, so a new week starts at zero even before the app runs again.
public struct WeekSnapshot: Codable, Sendable, Equatable {
    public struct Ride: Codable, Sendable, Equatable {
        public var start: Date
        /// Metres.
        public var distance: Double

        public init(start: Date, distance: Double) {
            self.start = start
            self.distance = distance
        }
    }

    public struct LastRide: Codable, Sendable, Equatable {
        public var name: String
        public var start: Date
        /// Metres.
        public var distance: Double
        /// Where the ride took place, for its date (`RideExchange.Ride.timeZone`).
        public var timeZone: String?

        public init(name: String, start: Date, distance: Double, timeZone: String? = nil) {
            self.name = name
            self.start = start
            self.distance = distance
            self.timeZone = timeZone
        }
    }

    /// The rides that count for the totals (no motorcycle rides), from the start of the week of
    /// the moment the snapshot was made; older rides are never needed by the widget.
    public var rides: [Ride]
    public var lastRide: LastRide?

    public init(rides: some Sequence<(start: Date, distance: Double)>, lastRide: LastRide?,
                now: Date = .now, calendar: Calendar = .current) {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        self.rides = rides.filter { $0.start >= weekStart }
            .map { Ride(start: $0.start, distance: $0.distance) }
            .sorted { $0.start < $1.start }
        self.lastRide = lastRide
    }

    /// No rides and no last ride, before the app has written anything.
    public static let empty = WeekSnapshot(rides: [(start: Date, distance: Double)](), lastRide: nil)

    /// Distance and number of rides in the week of `now`, the same sums as the overview.
    public func totals(now: Date = .now, calendar: Calendar = .current) -> RidePeriodTotals {
        RidePeriodTotals(rides: rides.map { (start: $0.start, distance: $0.distance) }, now: now, calendar: calendar)
    }

    /// The seven days of the week of `now`, in the order of the calendar, each with its metres.
    public func days(now: Date = .now, calendar: Calendar = .current) -> [(day: Date, distance: Double)] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<7).compactMap { offset -> (day: Date, distance: Double)? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let distance = rides.filter { calendar.isDate($0.start, inSameDayAs: day) }.reduce(0) { $0 + $1.distance }
            return (day: day, distance: distance)
        }
    }

    /// When the widget must draw again by itself: at the start of the next week.
    public static func nextWeek(after now: Date = .now, calendar: Calendar = .current) -> Date? {
        calendar.dateInterval(of: .weekOfYear, for: now)?.end
    }
}
