import Foundation

// Calculations for comparing 2–4 rides side by side (B-098: CMP-02 … CMP-04).
// Like the analysis, everything works on plain values, so it is testable without SwiftData.

/// The values of one ride that the comparison needs.
public struct ComparisonFigures: Sendable, Equatable {
    public var timerTime: TimeInterval
    public var elapsedTime: TimeInterval
    /// Metres.
    public var distance: Double
    /// Metres per second.
    public var averageSpeed: Double?
    public var maxSpeed: Double?
    /// Metres.
    public var totalAscent: Int?
    public var totalDescent: Int?
    public var minAltitude: Double?
    public var maxAltitude: Double?
    /// Watts; Bosch counts only seconds with pedal power.
    public var averagePower: Int?
    public var maxPower: Int?
    public var averageCadence: Int?
    public var maxCadence: Int?
    public var workKilojoules: Double
    /// When the ride started: the age for the calorie estimate "with profile" follows from it.
    /// `nil` where unknown (then today counts).
    public var startDate: Date?
    /// Seconds with pedal power. `nil` derives it from the Bosch values (see `pedallingTime`);
    /// a merged ride passes the sum of its parts.
    public var pedallingTimeOverride: TimeInterval?

    public init(timerTime: TimeInterval, elapsedTime: TimeInterval, distance: Double,
                averageSpeed: Double? = nil, maxSpeed: Double? = nil,
                totalAscent: Int? = nil, totalDescent: Int? = nil,
                minAltitude: Double? = nil, maxAltitude: Double? = nil,
                averagePower: Int? = nil, maxPower: Int? = nil,
                averageCadence: Int? = nil, maxCadence: Int? = nil,
                workKilojoules: Double = 0, pedallingTime: TimeInterval? = nil, startDate: Date? = nil) {
        self.timerTime = timerTime
        self.elapsedTime = elapsedTime
        self.distance = distance
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.totalAscent = totalAscent
        self.totalDescent = totalDescent
        self.minAltitude = minAltitude
        self.maxAltitude = maxAltitude
        self.averagePower = averagePower
        self.maxPower = maxPower
        self.averageCadence = averageCadence
        self.maxCadence = maxCadence
        self.workKilojoules = workKilojoules
        self.pedallingTimeOverride = pedallingTime
        self.startDate = startDate
    }

    public var pausedTime: TimeInterval { max(0, elapsedTime - timerTime) }

    /// `true` if the file held power; work and calories need it (B-146).
    public var hasPowerData: Bool { averagePower != nil || maxPower != nil }

    /// Seconds with pedal power. Bosch averages power only over those seconds, and the
    /// work is the sum of all seconds, so work ÷ average power gives their number
    /// without decoding the time series (for the sample ride 18.8 % coasting
    /// against 17.9 % counted from the samples).
    public var pedallingTime: TimeInterval? {
        if let pedallingTimeOverride { return pedallingTimeOverride }
        guard let averagePower, averagePower > 0, timerTime > 0 else { return nil }
        return min(timerTime, workKilojoules * 1000 / Double(averagePower))
    }
}

extension Ride {
    public var comparisonFigures: ComparisonFigures {
        // A merged ride's average power is weighted by moving time, so its pedalling
        // time comes from the parts, where Bosch's own averages still hold.
        // If a part has no power data, fall back to the merged values.
        let partTimes = (parts ?? []).map(\.comparisonFigures.pedallingTime)
        let pedalling: TimeInterval? = isMerged && !partTimes.contains(nil)
            ? partTimes.compactMap { $0 }.reduce(0, +)
            : nil
        return ComparisonFigures(
            timerTime: timerTime, elapsedTime: elapsedTime, distance: distance,
            averageSpeed: averageSpeed, maxSpeed: maxSpeed,
            totalAscent: totalAscent, totalDescent: totalDescent,
            minAltitude: minAltitude, maxAltitude: maxAltitude,
            averagePower: averagePower, maxPower: maxPower,
            averageCadence: averageCadence, maxCadence: maxCadence,
            workKilojoules: workKilojoules, pedallingTime: pedalling, startDate: startDate
        )
    }

    /// Counts towards totals and averages: not in the trash, not the sample ride,
    /// not a part of a merged ride (the merged ride counts instead).
    public var countsInStatistics: Bool {
        deletedAt == nil && !isSample && mergedInto == nil
    }
}

/// Which way a metric is "better" (CMP-02). Neutral metrics get no best value.
public enum ComparisonDirection: Sendable {
    case higherIsBetter, lowerIsBetter, neutral
}

/// The sections of the comparison table, in display order.
public enum ComparisonGroup: String, CaseIterable, Identifiable, Sendable {
    case ride, speed, elevation, power, estimates, perKilometre

    public var id: Self { self }

    public var metrics: [ComparisonMetric] { ComparisonMetric.allCases.filter { $0.group == self } }
}

/// One row of the comparison table: every value of the ride detail (CMP-02) plus
/// values that make rides of different length comparable (CMP-03).
public enum ComparisonMetric: String, CaseIterable, Identifiable, Sendable {
    case rideTime, totalTime, pausedTime, distance
    case averageSpeed, maxSpeed
    case ascent, descent, minAltitude, maxAltitude
    case averagePower, maxPower, averageCadence, maxCadence, work
    case calories, co2Saved
    case caloriesPerKilometre, ascentPerKilometre, workPerKilometre, coastingShare, averagePowerOverRideTime

    public var id: Self { self }

    public var group: ComparisonGroup {
        switch self {
        case .rideTime, .totalTime, .pausedTime, .distance: .ride
        case .averageSpeed, .maxSpeed: .speed
        case .ascent, .descent, .minAltitude, .maxAltitude: .elevation
        case .averagePower, .maxPower, .averageCadence, .maxCadence, .work: .power
        case .calories, .co2Saved: .estimates
        case .caloriesPerKilometre, .ascentPerKilometre, .workPerKilometre, .coastingShare, .averagePowerOverRideTime: .perKilometre
        }
    }

    /// Agreed with Nils on 21.10.2026: only these four have a direction.
    public var direction: ComparisonDirection {
        switch self {
        case .averageSpeed, .averagePower, .averagePowerOverRideTime: .higherIsBetter
        case .pausedTime: .lowerIsBetter
        default: .neutral
        }
    }

    /// Calories and CO₂ are estimates from the factors (Requirements 3.4).
    public var isEstimate: Bool {
        self == .calories || self == .co2Saved || self == .caloriesPerKilometre
    }

    /// The value of one ride, in base units: seconds, metres, m/s, W, rpm, kJ, kcal, kg,
    /// per kilometre, or a share from 0 to 1. `nil` when the ride has no such value.
    public func value(of ride: ComparisonFigures,
                      calories: CalorieModel = .fromWork,
                      co2PerKilometre: Double = RideMetrics.defaultCO2PerKilometre) -> Double? {
        let km = ride.distance / 1000
        switch self {
        case .rideTime: return ride.timerTime
        case .totalTime: return ride.elapsedTime
        case .pausedTime: return ride.pausedTime
        case .distance: return ride.distance
        case .averageSpeed: return ride.averageSpeed
        case .maxSpeed: return ride.maxSpeed
        case .ascent: return ride.totalAscent.map(Double.init)
        case .descent: return ride.totalDescent.map(Double.init)
        case .minAltitude: return ride.minAltitude
        case .maxAltitude: return ride.maxAltitude
        case .averagePower: return ride.averagePower.map(Double.init)
        case .maxPower: return ride.maxPower.map(Double.init)
        case .averageCadence: return ride.averageCadence.map(Double.init)
        case .maxCadence: return ride.maxCadence.map(Double.init)
        case .work: return ride.hasPowerData ? ride.workKilojoules : nil
        case .calories: return ride.hasPowerData ? calories.kilocalories(for: ride) : nil
        case .co2Saved: return km * co2PerKilometre
        case .caloriesPerKilometre: return km > 0 && ride.hasPowerData ? calories.kilocalories(for: ride) / km : nil
        case .ascentPerKilometre: return km > 0 ? ride.totalAscent.map { Double($0) / km } : nil
        case .workPerKilometre: return km > 0 && ride.hasPowerData ? ride.workKilojoules / km : nil
        case .coastingShare:
            guard let pedalling = ride.pedallingTime, ride.timerTime > 0 else { return nil }
            return max(0, 1 - pedalling / ride.timerTime)
        case .averagePowerOverRideTime:
            return ride.timerTime > 0 && ride.averagePower != nil ? ride.workKilojoules * 1000 / ride.timerTime : nil
        }
    }

    /// The average of the metric over many rides (CMP-04), as one typical ride.
    /// Averages of a ride (speed, power, cadence) are weighted by ride time like in
    /// the analysis, per-kilometre values by distance and the coasting share by ride
    /// time; everything else is the plain mean per ride. Rides without the value are skipped.
    public func average(over rides: [ComparisonFigures],
                        calories: CalorieModel = .fromWork,
                        co2PerKilometre: Double = RideMetrics.defaultCO2PerKilometre) -> Double? {
        let weight: (ComparisonFigures) -> Double? = switch self {
        case .averageSpeed, .averagePower, .averageCadence, .averagePowerOverRideTime, .coastingShare: { $0.timerTime }
        case .caloriesPerKilometre, .ascentPerKilometre, .workPerKilometre: { $0.distance }
        default: { _ in 1 }
        }
        var sum = 0.0
        var total = 0.0
        for ride in rides {
            guard let w = weight(ride), w > 0,
                  let v = value(of: ride, calories: calories, co2PerKilometre: co2PerKilometre) else { continue }
            sum += v * w
            total += w
        }
        return total > 0 ? sum / total : nil
    }
}

/// Difference of a value from the average (CMP-04).
public struct ComparisonDeviation: Sendable, Equatable {
    /// Value minus average, in the metric's base unit.
    public var absolute: Double
    /// `0.12` means 12 % above the average; `nil` when the average is 0.
    public var relative: Double?
}

/// 2–4 rides side by side (CMP-01 … CMP-04).
public struct RideComparison: Sendable {
    /// How many rides can be compared (CMP-01).
    public static let allowedCount = 2...4

    public var rides: [ComparisonFigures]
    /// Averages over all rides that count (CMP-04), per metric.
    public var averages: [ComparisonMetric: Double]
    /// How many of the baseline rides have the value of each metric: the average is taken over those
    /// (B-146, "9 of 12 rides").
    public var coverage: [ComparisonMetric: ValueCoverage]
    public var calories: CalorieModel
    public var co2PerKilometre: Double

    /// - Parameters:
    ///   - rides: the compared rides, in column order.
    ///   - baseline: all rides the averages are taken from, usually every ride with `countsInStatistics`.
    public init(rides: [ComparisonFigures], baseline: [ComparisonFigures],
                calories: CalorieModel = .fromWork,
                co2PerKilometre: Double = RideMetrics.defaultCO2PerKilometre) {
        self.rides = rides
        self.calories = calories
        self.co2PerKilometre = co2PerKilometre
        var averages: [ComparisonMetric: Double] = [:]
        var coverage: [ComparisonMetric: ValueCoverage] = [:]
        for metric in ComparisonMetric.allCases {
            averages[metric] = metric.average(over: baseline, calories: calories, co2PerKilometre: co2PerKilometre)
            coverage[metric] = ValueCoverage(
                have: baseline.count { metric.value(of: $0, calories: calories, co2PerKilometre: co2PerKilometre) != nil },
                total: baseline.count)
        }
        self.averages = averages
        self.coverage = coverage
    }

    /// `true` for 2 to 4 rides.
    public static func canCompare(count: Int) -> Bool { allowedCount.contains(count) }

    /// The values of one row, one per ride (`nil` where a ride has none).
    public func values(_ metric: ComparisonMetric) -> [Double?] {
        rides.map { metric.value(of: $0, calories: calories, co2PerKilometre: co2PerKilometre) }
    }

    /// The columns with the best value of the row (CMP-02); several when they tie.
    /// Empty for neutral metrics, when fewer than two rides have the value, or when all are equal.
    public func bestIndices(_ metric: ComparisonMetric, tolerance: Double = 1e-9) -> Set<Int> {
        let indexed = values(metric).enumerated().compactMap { i, v in v.map { (i, $0) } }
        guard indexed.count >= 2 else { return [] }
        let best: Double
        switch metric.direction {
        case .neutral: return []
        case .higherIsBetter: best = indexed.map(\.1).max()!
        case .lowerIsBetter: best = indexed.map(\.1).min()!
        }
        let winners = indexed.filter { abs($0.1 - best) <= tolerance }.map(\.0)
        return winners.count == indexed.count ? [] : Set(winners)
    }

    /// How far a ride's value is from the average (CMP-04); `nil` without a value or an average.
    public func deviation(_ metric: ComparisonMetric, ride index: Int) -> ComparisonDeviation? {
        guard rides.indices.contains(index),
              let value = values(metric)[index], let average = averages[metric] else { return nil }
        let difference = value - average
        return ComparisonDeviation(absolute: difference, relative: average != 0 ? difference / abs(average) : nil)
    }
}
