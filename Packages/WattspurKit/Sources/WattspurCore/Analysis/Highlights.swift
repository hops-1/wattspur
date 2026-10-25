import Foundation

// Calculations for "Highlights" (v1.3: ADV-J1, ADV-R1, ADV-R2, ADV-Z1, LIST-04).
// Like the analysis, everything works on plain values, so it is testable without SwiftData.
// Callers pass only rides that count in statistics: no sample ride, no trash, and a
// merged ride instead of its parts (Requirements 10.10).

/// One ride as the highlights see it.
public struct HighlightRide: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var figures: RideFigures
    /// Time zone of the start location: a ride belongs to the calendar day where it started.
    public var timeZone: TimeZone

    public init(id: UUID = UUID(), figures: RideFigures, timeZone: TimeZone) {
        self.id = id
        self.figures = figures
        self.timeZone = timeZone
    }

    public var startDate: Date { figures.startDate }

    /// The start time as a date whose wall-clock time in `calendar` equals the local
    /// time at the start location. A ride at 23:30 in Lisbon belongs to that day, even
    /// when the Mac is set to Berlin.
    public func localStartDate(in calendar: Calendar) -> Date {
        let shift = timeZone.secondsFromGMT(for: startDate) - calendar.timeZone.secondsFromGMT(for: startDate)
        return startDate.addingTimeInterval(TimeInterval(shift))
    }
}

// MARK: - Records (ADV-R1, ADV-R2)

public enum RecordKind: String, CaseIterable, Identifiable, Sendable {
    case longestDistance, longestDuration, mostAscent, highestAverageSpeed, highestAveragePower, longestStreak

    public var id: Self { self }

    /// Average speed and power count only from this distance on (metres), so a short
    /// ride downhill sets no record (Requirements 10.10).
    public static let minimumDistanceForAverages = 5_000.0

    /// The value of one ride: metres, seconds, metres, m/s, watts. `nil` for the streak,
    /// which is not a value of one ride, and for averages of short rides.
    public func value(of ride: RideFigures) -> Double? {
        switch self {
        case .longestDistance: ride.distance > 0 ? ride.distance : nil
        case .longestDuration: ride.timerTime > 0 ? ride.timerTime : nil
        case .mostAscent: ride.totalAscent.flatMap { $0 > 0 ? Double($0) : nil }
        case .highestAverageSpeed:
            ride.distance >= Self.minimumDistanceForAverages ? ride.averageSpeed : nil
        case .highestAveragePower:
            ride.distance >= Self.minimumDistanceForAverages ? ride.averagePower.map(Double.init) : nil
        case .longestStreak: nil
        }
    }

    /// Records of single rides; the streak spans several.
    public var isRideRecord: Bool { self != .longestStreak }
}

/// Consecutive calendar days with at least one ride.
public struct DayStreak: Sendable, Equatable {
    /// Start of the first and of the last day, in the calendar used to compute it.
    public var firstDay: Date
    public var lastDay: Date
    public var days: Int
    public var rideIDs: [UUID]
}

/// A best value and where it comes from.
public struct RideRecord: Sendable, Equatable, Identifiable {
    public var kind: RecordKind
    /// Metres, seconds, metres, m/s, watts or days.
    public var value: Double
    /// The ride that holds the record; for the streak, all rides of the streak.
    public var rideIDs: [UUID]
    /// Start of the ride, or the first day of the streak.
    public var date: Date
    /// Set for the streak.
    public var streak: DayStreak?

    public var id: RecordKind { kind }
}

/// A record broken by newly imported rides (ADV-R2).
public struct RecordBreak: Sendable, Equatable, Identifiable {
    public var kind: RecordKind
    public var value: Double
    public var previousValue: Double
    /// The imported ride that set it; for the streak the newest imported ride in it.
    public var rideID: UUID

    public var id: RecordKind { kind }
}

public enum RideRecords {
    /// The best value of each kind, in `RecordKind` order; kinds without any value are
    /// left out. On a tie the earlier ride keeps the record: it got there first.
    public static func records(_ rides: [HighlightRide], calendar: Calendar = .current) -> [RideRecord] {
        let sorted = rides.sorted { $0.startDate < $1.startDate }
        var result: [RideRecord] = []
        for kind in RecordKind.allCases {
            if kind == .longestStreak {
                if let streak = longestStreak(sorted, calendar: calendar) {
                    result.append(RideRecord(kind: kind, value: Double(streak.days), rideIDs: streak.rideIDs,
                                             date: streak.firstDay, streak: streak))
                }
                continue
            }
            var best: (value: Double, ride: HighlightRide)?
            for ride in sorted {
                guard let value = kind.value(of: ride.figures) else { continue }
                if value > best?.value ?? -.infinity { best = (value, ride) }
            }
            if let best {
                result.append(RideRecord(kind: kind, value: best.value, rideIDs: [best.ride.id], date: best.ride.startDate))
            }
        }
        return result
    }

    /// The longest run of consecutive calendar days with a ride, by the local date at the
    /// start location. On a tie the earlier streak counts. A single day is no streak.
    public static func longestStreak(_ rides: [HighlightRide], calendar: Calendar = .current) -> DayStreak? {
        // Day number → rides on that day.
        var byDay: [Int: [HighlightRide]] = [:]
        for ride in rides {
            byDay[dayNumber(ride.localStartDate(in: calendar), calendar: calendar), default: []].append(ride)
        }
        let days = byDay.keys.sorted()
        guard var runStart = days.first else { return nil }
        var best = (start: runStart, end: runStart)
        var previous = runStart
        for day in days.dropFirst() {
            if day != previous + 1 { runStart = day }
            if day - runStart > best.end - best.start { best = (runStart, day) }
            previous = day
        }
        guard best.end > best.start else { return nil }
        let streakRides = (best.start...best.end).flatMap { byDay[$0] ?? [] }.sorted { $0.startDate < $1.startDate }
        let firstLocal = streakRides[0].localStartDate(in: calendar)
        let lastLocal = streakRides[streakRides.count - 1].localStartDate(in: calendar)
        return DayStreak(firstDay: calendar.startOfDay(for: firstLocal), lastDay: calendar.startOfDay(for: lastLocal),
                         days: best.end - best.start + 1, rideIDs: streakRides.map(\.id))
    }

    /// Records the imported rides broke. A record counts as broken only if there was
    /// one before, so the very first import does not announce every value as a record.
    public static func newRecords(existing: [HighlightRide], imported: [HighlightRide],
                                  calendar: Calendar = .current) -> [RecordBreak] {
        let importedIDs = Set(imported.map(\.id))
        let existing = existing.filter { !importedIDs.contains($0.id) }
        let before = Dictionary(uniqueKeysWithValues: records(existing, calendar: calendar).map { ($0.kind, $0) })
        let byID = Dictionary(uniqueKeysWithValues: imported.map { ($0.id, $0) })
        return records(existing + imported, calendar: calendar).compactMap { record in
            guard let previous = before[record.kind], record.value > previous.value else { return nil }
            let setBy = record.rideIDs.compactMap { byID[$0] }.max { $0.startDate < $1.startDate }
            guard let setBy else { return nil }
            return RecordBreak(kind: record.kind, value: record.value, previousValue: previous.value, rideID: setBy.id)
        }
    }

    /// The ride records a ride holds right now, for the badge in the ride detail.
    /// The streak is left out: it belongs to several rides.
    public static func kinds(heldBy rideID: UUID, in records: [RideRecord]) -> [RecordKind] {
        records.filter { $0.kind.isRideRecord && $0.rideIDs.contains(rideID) }.map(\.kind)
    }

    /// Days since 1 January 1970 of the calendar day that contains `date`.
    static func dayNumber(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let midnight = utc.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day)) ?? date
        return Int((midnight.timeIntervalSince1970 / 86_400).rounded(.down))
    }
}

// MARK: - Year in review (ADV-J1, LIST-04)

/// A day with at least one ride, for the calendar heatmap.
public struct RidingDay: Sendable, Equatable, Identifiable {
    /// Start of the day in the calendar used for the review.
    public var date: Date
    /// Metres.
    public var distance: Double
    public var rideIDs: [UUID]

    public var id: Date { date }
    public var level: Int { HeatLevel.level(forDistance: distance) }
}

/// The five shades of the heatmap: 0 = no ride, then < 10, 10–25, 25–50 and ≥ 50 km.
public enum HeatLevel {
    /// Lower bounds in kilometres of the levels 2, 3 and 4.
    public static let thresholds = [10.0, 25.0, 50.0]

    public static func level(forDistance metres: Double) -> Int {
        guard metres > 0 else { return 0 }
        let km = metres / 1000
        return 1 + thresholds.filter { km >= $0 }.count
    }
}

public struct YearReview: Sendable, Equatable {
    public var year: Int
    public var aggregate: RideAggregate
    /// Distance of the year before in metres, `nil` without rides then.
    public var previousYearDistance: Double?
    /// January to December.
    public var months: [RideAggregate]
    /// Only days with rides, oldest first.
    public var days: [RidingDay]
    /// The records of this year alone.
    public var records: [RideRecord]

    public var ridingDayCount: Int { days.count }

    /// Change of distance against the previous year (`0.18` = +18 %).
    public var distanceChange: Double? { Change.relative(from: previousYearDistance, to: aggregate.distance) }

    /// Index (0–11) of the month with the most distance, `nil` without rides.
    public var bestMonth: Int? {
        guard aggregate.rideCount > 0 else { return nil }
        return months.indices.max { months[$0].distance < months[$1].distance }
    }

    public init(_ rides: [HighlightRide], year: Int, calendar: Calendar = .current) {
        self.year = year
        let inYear = rides.filter { Self.year(of: $0, calendar: calendar) == year }
        aggregate = RideAggregate(inYear.map(\.figures))
        let previous = rides.filter { Self.year(of: $0, calendar: calendar) == year - 1 }
        previousYearDistance = previous.isEmpty ? nil : RideAggregate(previous.map(\.figures)).distance
        months = (1...12).map { month in
            RideAggregate(inYear.filter { calendar.component(.month, from: $0.localStartDate(in: calendar)) == month }.map(\.figures))
        }
        var byDay: [Date: RidingDay] = [:]
        for ride in inYear.sorted(by: { $0.startDate < $1.startDate }) {
            let day = calendar.startOfDay(for: ride.localStartDate(in: calendar))
            byDay[day, default: RidingDay(date: day, distance: 0, rideIDs: [])].distance += ride.figures.distance
            byDay[day]?.rideIDs.append(ride.id)
        }
        days = byDay.values.sorted { $0.date < $1.date }
        records = RideRecords.records(inYear, calendar: calendar)
    }

    /// Years with at least one ride, newest first.
    public static func years(of rides: [HighlightRide], calendar: Calendar = .current) -> [Int] {
        Set(rides.map { year(of: $0, calendar: calendar) }).sorted(by: >)
    }

    static func year(of ride: HighlightRide, calendar: Calendar) -> Int {
        calendar.component(.year, from: ride.localStartDate(in: calendar))
    }
}

// MARK: - Goals (ADV-Z1)

public enum GoalMetric: String, CaseIterable, Identifiable, Sendable {
    case distance, rides, ascent

    public var id: Self { self }

    /// Metres, a count or metres.
    public func value(of aggregate: RideAggregate) -> Double {
        switch self {
        case .distance: aggregate.distance
        case .rides: Double(aggregate.rideCount)
        case .ascent: aggregate.ascent
        }
    }
}

public enum GoalPeriod: String, CaseIterable, Identifiable, Sendable {
    case week, month, year

    public var id: Self { self }

    public var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    /// How many past periods the small history under a goal shows.
    public var historyCount: Int {
        switch self {
        case .week, .month: 8
        case .year: 3
        }
    }

    /// Weeks run from Monday to Sunday, whatever the Mac is set to (Requirements 10.10).
    public static func calendar(from base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}

/// One period of a goal: how far it got.
public struct GoalPeriodResult: Sendable, Equatable, Identifiable {
    public var interval: DateInterval
    public var value: Double
    public var target: Double

    public var id: Date { interval.start }
    public var fraction: Double { target > 0 ? value / target : 0 }
    public var isReached: Bool { target > 0 && value >= target }
}

public struct GoalProgress: Sendable, Equatable {
    public var metric: GoalMetric
    public var period: GoalPeriod
    /// The current period.
    public var current: GoalPeriodResult
    /// Start of the ride that reached the target, `nil` while it is not reached.
    public var reachedAt: Date?
    /// Share of the current period that has passed at `now`, 0…1.
    public var elapsedFraction: Double
    /// The past periods, oldest first, without the current one.
    public var history: [GoalPeriodResult]
    /// For how many rides of the current period the ascent is known: rides without elevation add
    /// nothing to an ascent goal (B-146).
    public var ascentCoverage: ValueCoverage

    public var remaining: Double { max(0, current.target - current.value) }

    /// `true` if the goal is at least as far as the time that has passed.
    public var isOnTrack: Bool { current.isReached || current.fraction >= elapsedFraction }

    /// Pass a calendar from `GoalPeriod.calendar(from:)`, so weeks start on Monday.
    public init(metric: GoalMetric, period: GoalPeriod, target: Double, rides: [HighlightRide],
                now: Date = .now, calendar: Calendar) {
        self.metric = metric
        self.period = period
        let local = rides.map { (ride: $0, date: $0.localStartDate(in: calendar)) }.sorted { $0.date < $1.date }
        func result(for interval: DateInterval) -> GoalPeriodResult {
            let inside = local.filter { interval.start <= $0.date && $0.date < interval.end }.map(\.ride.figures)
            return GoalPeriodResult(interval: interval, value: metric.value(of: RideAggregate(inside)), target: target)
        }
        let interval = calendar.dateInterval(of: period.component, for: now) ?? DateInterval(start: now, duration: 0)
        current = result(for: interval)
        ascentCoverage = RideAggregate(local.filter { interval.start <= $0.date && $0.date < interval.end }.map(\.ride.figures)).ascentCoverage
        elapsedFraction = interval.duration > 0 ? min(1, max(0, now.timeIntervalSince(interval.start) / interval.duration)) : 1

        // The ride that pushed the running total over the target.
        reachedAt = nil
        if target > 0 {
            var running: [RideFigures] = []
            for entry in local where interval.start <= entry.date && entry.date < interval.end {
                running.append(entry.ride.figures)
                if metric.value(of: RideAggregate(running)) >= target {
                    reachedAt = entry.ride.startDate
                    break
                }
            }
        }

        history = (1...period.historyCount).reversed().compactMap { steps in
            guard let date = calendar.date(byAdding: period.component, value: -steps, to: interval.start),
                  let past = calendar.dateInterval(of: period.component, for: date) else { return nil }
            return result(for: past)
        }
    }
}
