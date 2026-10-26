import Foundation

// Calculations for the "Analysis" section (v0.2: AGG-01 … AGG-04, TREND-01, TREND-02).
// Everything works on plain values (`RideFigures`), so it is testable without SwiftData.

/// The values of one ride that the analysis needs.
public struct RideFigures: Sendable, Equatable {
    public var startDate: Date
    /// Metres.
    public var distance: Double
    /// Seconds in motion (Bosch `total_timer_time`); the weight for averages.
    public var timerTime: TimeInterval
    /// Metres.
    public var totalAscent: Int?
    public var workKilojoules: Double
    /// Metres per second.
    public var averageSpeed: Double?
    public var averagePower: Int?
    public var averageCadence: Int?
    /// The peaks, for the records (B-122): metres per second, watts, revolutions per minute.
    public var maxSpeed: Double?
    public var maxPower: Int?
    public var maxCadence: Int?
    /// The best average power over one minute, in watts (`PeakPower`).
    public var bestPower1Min: Int?

    public init(startDate: Date, distance: Double, timerTime: TimeInterval, totalAscent: Int? = nil,
                workKilojoules: Double = 0, averageSpeed: Double? = nil, averagePower: Int? = nil,
                averageCadence: Int? = nil, maxSpeed: Double? = nil, maxPower: Int? = nil,
                maxCadence: Int? = nil, bestPower1Min: Int? = nil) {
        self.startDate = startDate
        self.distance = distance
        self.timerTime = timerTime
        self.totalAscent = totalAscent
        self.workKilojoules = workKilojoules
        self.averageSpeed = averageSpeed
        self.averagePower = averagePower
        self.averageCadence = averageCadence
        self.maxSpeed = maxSpeed
        self.maxPower = maxPower
        self.maxCadence = maxCadence
        self.bestPower1Min = bestPower1Min
    }
}

extension RideFigures {
    /// `true` if the file held power: work and calories come from it (B-146). A GPX file often has none.
    public var hasPowerData: Bool { averagePower != nil }
}

// MARK: - Sums and averages (AGG-01, AGG-02)

/// For how many of the rides a value exists (B-146): "9 of 12 rides". A figure that rides lack,
/// like the power of a GPX file, is summed or averaged over the others and says so.
public struct ValueCoverage: Sendable, Equatable {
    /// Rides that have the value.
    public var have: Int
    /// All rides.
    public var total: Int

    public init(have: Int, total: Int) {
        self.have = have
        self.total = total
    }

    /// No ride has it, so there is no figure to show (a dash).
    public var isNone: Bool { total > 0 && have == 0 }
    /// Some rides have it and some do not: the figure needs the note.
    public var isPartial: Bool { have > 0 && have < total }
    public var isComplete: Bool { have == total }
}

/// Sums and time-weighted averages over a set of rides.
public struct RideAggregate: Sendable, Equatable {
    public var rideCount = 0
    /// Metres.
    public var distance = 0.0
    public var timerTime: TimeInterval = 0
    /// Metres; rides without a value count as 0 (see `ascentCoverage`).
    public var ascent = 0.0
    /// Work and calories of the rides that have power; the others add nothing (see `powerCoverage`).
    public var workKilojoules = 0.0
    public var kilocalories = 0.0
    public var co2SavedKilograms = 0.0
    /// Averages weighted by ride time from the Bosch averages of each ride (Requirements 3.3).
    /// `nil` when no ride has the value. Speed in m/s.
    public var averageSpeed: Double?
    public var averagePower: Double?
    public var averageCadence: Double?
    /// How many of the rides have power (work, calories, average power), cadence and ascent (B-146).
    public var powerCoverage = ValueCoverage(have: 0, total: 0)
    public var cadenceCoverage = ValueCoverage(have: 0, total: 0)
    public var ascentCoverage = ValueCoverage(have: 0, total: 0)

    public static let empty = RideAggregate()

    private init() {}

    public init(_ rides: [RideFigures],
                calories: CalorieModel = .fromWork,
                co2PerKilometre: Double = RideMetrics.defaultCO2PerKilometre) {
        rideCount = rides.count
        for ride in rides {
            distance += ride.distance
            timerTime += ride.timerTime
            ascent += Double(ride.totalAscent ?? 0)
            // Without power there is no work, and a ride's calories would be only the time share.
            if ride.hasPowerData {
                workKilojoules += ride.workKilojoules
                kilocalories += calories.kilocalories(for: ride)
            }
        }
        powerCoverage = ValueCoverage(have: rides.count { $0.hasPowerData }, total: rides.count)
        cadenceCoverage = ValueCoverage(have: rides.count { $0.averageCadence != nil }, total: rides.count)
        ascentCoverage = ValueCoverage(have: rides.count { $0.totalAscent != nil }, total: rides.count)
        co2SavedKilograms = distance / 1000 * co2PerKilometre
        averageSpeed = Self.weightedAverage(rides) { $0.averageSpeed }
        averagePower = Self.weightedAverage(rides) { $0.averagePower.map(Double.init) }
        averageCadence = Self.weightedAverage(rides) { $0.averageCadence.map(Double.init) }
    }

    /// Work and calories, `nil` when no ride has power: then there is nothing to show but a dash, and
    /// nothing to compare with the period before (B-146).
    public var workKilojoulesIfKnown: Double? { powerCoverage.isNone ? nil : workKilojoules }
    public var kilocaloriesIfKnown: Double? { powerCoverage.isNone ? nil : kilocalories }
    /// Ascent, `nil` when no ride has it.
    public var ascentIfKnown: Double? { ascentCoverage.isNone ? nil : ascent }

    /// Mean distance per ride in metres (AGG-02).
    public var distancePerRide: Double? { rideCount > 0 ? distance / Double(rideCount) : nil }
    /// Mean ride time per ride (AGG-02).
    public var timerTimePerRide: TimeInterval? { rideCount > 0 ? timerTime / Double(rideCount) : nil }

    /// Σ(value × ride time) / Σ ride time, over the rides that have the value.
    /// A long ride counts more than a short one, as if all rides were one long ride.
    static func weightedAverage(_ rides: [RideFigures], _ value: (RideFigures) -> Double?) -> Double? {
        var sum = 0.0
        var weight = 0.0
        for ride in rides where ride.timerTime > 0 {
            guard let v = value(ride) else { continue }
            sum += v * ride.timerTime
            weight += ride.timerTime
        }
        return weight > 0 ? sum / weight : nil
    }
}

/// Relative change between two values (TREND-02).
public enum Change {
    /// `0.12` means +12 %. `nil` when there is nothing to compare with (no or zero previous value).
    public static func relative(from previous: Double?, to current: Double?) -> Double? {
        guard let previous, let current, previous != 0 else { return nil }
        return (current - previous) / previous
    }
}

// MARK: - Period (AGG-03)

/// The period choices at the top of the analysis.
public enum AnalysisPeriodKind: String, CaseIterable, Identifiable, Sendable {
    case week, month, year, custom, all

    public var id: Self { self }

    /// Week, month and year can be stepped back with ‹ ›.
    public var isSteppable: Bool { self == .week || self == .month || self == .year }

    /// The bar chart grouping that fits the period (AGG-04).
    public var defaultGrouping: AnalysisGrouping {
        switch self {
        case .week: .day
        case .month, .custom: .week
        case .year, .all: .month
        }
    }
}

/// A concrete period: kind plus how many steps back (`offset` ≤ 0), or a custom interval.
public struct AnalysisPeriod: Hashable, Sendable {
    public var kind: AnalysisPeriodKind
    /// 0 = the current week/month/year, -1 = the one before, …
    public var offset: Int
    /// Used for `.custom`.
    public var customInterval: DateInterval?

    public init(kind: AnalysisPeriodKind, offset: Int = 0, customInterval: DateInterval? = nil) {
        self.kind = kind
        self.offset = min(0, offset)
        self.customInterval = customInterval
    }

    /// The date interval; `nil` means all rides. Week, month and year reuse `RidePeriod`
    /// from the list, shifted by `offset`.
    public func interval(now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch kind {
        case .week: shifted(.weekOfYear, by: offset, now: now, calendar: calendar, period: .thisWeek)
        case .month: shifted(.month, by: offset, now: now, calendar: calendar, period: .thisMonth)
        case .year: shifted(.year, by: offset, now: now, calendar: calendar, period: .thisYear)
        case .custom: customInterval ?? RidePeriod.last30Days.interval(now: now, calendar: calendar)
        case .all: nil
        }
    }

    /// The period before, for the comparison (TREND-02): the whole previous week, month or
    /// year, or for a custom period the same length directly before. `nil` for "all".
    public func previousInterval(now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch kind {
        case .week, .month, .year:
            var previous = self
            previous.offset -= 1
            return previous.interval(now: now, calendar: calendar)
        case .custom:
            guard let current = interval(now: now, calendar: calendar) else { return nil }
            return DateInterval(start: current.start.addingTimeInterval(-current.duration), duration: current.duration)
        case .all:
            return nil
        }
    }

    private func shifted(_ component: Calendar.Component, by steps: Int, now: Date, calendar: Calendar,
                         period: RidePeriod) -> DateInterval? {
        let date = calendar.date(byAdding: component, value: steps, to: now) ?? now
        return period.interval(now: date, calendar: calendar)
    }
}

// MARK: - Buckets for the bar chart (AGG-04, TREND-02)

public enum AnalysisGrouping: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year

    public var id: Self { self }

    public var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
}

/// One bar: a day, week, month or year with its rides summed up.
public struct RideBucket: Sendable, Equatable, Identifiable {
    public var interval: DateInterval
    public var aggregate: RideAggregate
    public var id: Date { interval.start }
}

/// What the bars and trends show.
public enum TrendMetric: String, CaseIterable, Identifiable, Sendable {
    case averagePower, averageCadence, averageSpeed

    public var id: Self { self }

    /// The value of one ride (speed in m/s).
    public func value(of ride: RideFigures) -> Double? {
        switch self {
        case .averagePower: ride.averagePower.map(Double.init)
        case .averageCadence: ride.averageCadence.map(Double.init)
        case .averageSpeed: ride.averageSpeed
        }
    }

    /// The time-weighted value of a set of rides.
    public func value(of aggregate: RideAggregate) -> Double? {
        switch self {
        case .averagePower: aggregate.averagePower
        case .averageCadence: aggregate.averageCadence
        case .averageSpeed: aggregate.averageSpeed
        }
    }
}

/// One ride in a trend chart: its value and the moving average up to it (TREND-01).
public struct TrendPoint: Sendable, Equatable {
    public var date: Date
    public var value: Double
    public var movingAverage: Double
}

public enum RideAnalysis {
    /// Rides inside the interval (`nil` = all), oldest first.
    public static func rides(_ rides: [RideFigures], in interval: DateInterval?) -> [RideFigures] {
        rides
            .filter { ride in interval.map { $0.start <= ride.startDate && ride.startDate < $0.end } ?? true }
            .sorted { $0.startDate < $1.startDate }
    }

    /// The interval to chart for "all": from the first ride to `now`.
    public static func span(of rides: [RideFigures], now: Date = .now) -> DateInterval? {
        guard let first = rides.map(\.startDate).min() else { return nil }
        return DateInterval(start: min(first, now), end: max(now, rides.map(\.startDate).max() ?? now))
    }

    /// Splits the interval into calendar days, weeks, months or years, including empty ones,
    /// so gaps show as missing bars. At most `limit` buckets.
    public static func buckets(_ rides: [RideFigures], grouping: AnalysisGrouping, in interval: DateInterval,
                               calendar: Calendar = .current, limit: Int = 2000) -> [RideBucket] {
        let sorted = Self.rides(rides, in: nil)
        var result: [RideBucket] = []
        var cursor = interval.start
        while cursor < interval.end, result.count < limit,
              let bucket = calendar.dateInterval(of: grouping.component, for: cursor) {
            let inside = sorted.filter { bucket.start <= $0.startDate && $0.startDate < bucket.end }
            result.append(RideBucket(interval: bucket, aggregate: RideAggregate(inside)))
            cursor = bucket.end
        }
        return result
    }

    /// Trailing moving average: each value is the mean of itself and up to `window − 1` values before it.
    public static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        let window = max(1, window)
        var result: [Double] = []
        result.reserveCapacity(values.count)
        var sum = 0.0
        for (i, value) in values.enumerated() {
            sum += value
            if i >= window { sum -= values[i - window] }
            result.append(sum / Double(min(i + 1, window)))
        }
        return result
    }

    /// One point per ride that has the value, oldest first, with a moving average over `window` rides.
    public static func trend(_ rides: [RideFigures], metric: TrendMetric, window: Int = 5) -> [TrendPoint] {
        let points = Self.rides(rides, in: nil).compactMap { ride in metric.value(of: ride).map { (ride.startDate, $0) } }
        let averages = movingAverage(points.map(\.1), window: window)
        return zip(points, averages).map { TrendPoint(date: $0.0, value: $0.1, movingAverage: $1) }
    }
}
