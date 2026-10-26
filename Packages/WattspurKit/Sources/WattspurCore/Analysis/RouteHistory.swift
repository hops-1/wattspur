import Foundation

/// How the rides on one route develop over time: ride time, speed, power and cadence, the best
/// and the latest ride marked, and how the latest compares with the average (B-120, ROUTE-06).
///
/// A ride that has no value for a metric (no power meter, no cadence) is left out of that metric's
/// series; the series says how many rides have it, so the view can say "9 of 12 rides".
public struct RouteHistory: Sendable, Equatable {
    public enum Metric: String, CaseIterable, Identifiable, Sendable {
        case duration, averageSpeed, averagePower, averageCadence

        public var id: Self { self }

        /// For the ride time the shortest is the best; for the others the highest.
        public var lowerIsBetter: Bool { self == .duration }

        /// The value of one ride: seconds in motion, metres per second, watts, revolutions per minute.
        public func value(of ride: RideFigures) -> Double? {
            switch self {
            case .duration: ride.timerTime > 0 ? ride.timerTime : nil
            case .averageSpeed: ride.averageSpeed
            case .averagePower: ride.averagePower.map(Double.init)
            case .averageCadence: ride.averageCadence.map(Double.init)
            }
        }
    }

    /// One metric over time, oldest ride first. `points` and `rideIDs` belong together by position.
    public struct Series: Sendable, Equatable {
        public var metric: Metric
        public var points: [TrendPoint]
        public var rideIDs: [UUID]
        /// All rides on the route, with or without a value.
        public var total: Int
        /// The plain mean of the values.
        public var mean: Double?
        public var bestIndex: Int?
        /// The latest ride that has a value.
        public var lastIndex: Int?

        public var count: Int { points.count }
        /// Do all rides have the value?
        public var isComplete: Bool { points.count == total }
        public var best: TrendPoint? { bestIndex.map { points[$0] } }
        public var last: TrendPoint? { lastIndex.map { points[$0] } }

        /// How the latest value differs from the mean, `0.05` is +5 % (`nil` with fewer than two rides).
        public var changeOfLast: Double? {
            guard points.count >= 2, let last else { return nil }
            return Change.relative(from: mean, to: last.value)
        }
    }

    /// The rides on the route, oldest first.
    public let rides: [HighlightRide]

    public init(_ rides: [HighlightRide]) {
        self.rides = rides.sorted { ($0.startDate, $0.id.uuidString) < ($1.startDate, $1.id.uuidString) }
    }

    public func series(_ metric: Metric, window: Int = 5) -> Series {
        let valued = rides.compactMap { ride in metric.value(of: ride.figures).map { (ride, $0) } }
        let averages = RideAnalysis.movingAverage(valued.map(\.1), window: window)
        let points = zip(valued, averages).map { TrendPoint(date: $0.0.startDate, value: $0.1, movingAverage: $1) }
        var best: Int?
        for (index, entry) in valued.enumerated() {
            guard let current = best else { best = index; continue }
            let better = metric.lowerIsBetter ? entry.1 < valued[current].1 : entry.1 > valued[current].1
            if better { best = index }
        }
        let values = valued.map(\.1)
        return Series(metric: metric, points: points, rideIDs: valued.map(\.0.id), total: rides.count,
                      mean: values.isEmpty ? nil : values.reduce(0, +) / Double(values.count),
                      bestIndex: best, lastIndex: valued.indices.last)
    }
}
