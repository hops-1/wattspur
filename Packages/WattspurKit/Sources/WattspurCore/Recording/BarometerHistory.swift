import Foundation

/// The barometer readings of the last half hour by the time they were measured (B-369). A GPS position
/// may be handled seconds or minutes after it was measured; it then takes the reading of its own
/// moment, not the newest one. Before, a delay of more than five seconds left the ride without height.
public struct BarometerHistory: Sendable, Equatable {
    /// A reading further away than this from a position does not belong to it.
    public static let tolerance: TimeInterval = 5
    /// Seconds kept before the newest reading.
    public static let span: TimeInterval = 1800

    private struct Reading: Sendable, Equatable {
        var date: Date
        var metres: Double
    }
    private var readings: [Reading] = []

    public init() {}

    public var count: Int { readings.count }

    public mutating func add(metres: Double, at date: Date) {
        let reading = Reading(date: date, metres: metres)
        if let last = readings.last, last.date > date {
            readings.insert(reading, at: firstIndex(notBefore: date))
        } else {
            readings.append(reading)
        }
        // Removed in one go now and then, not one from the front with every reading.
        if let first = readings.first, let last = readings.last,
           last.date.timeIntervalSince(first.date) > Self.span * 2 {
            readings.removeFirst(firstIndex(notBefore: last.date.addingTimeInterval(-Self.span)))
        }
    }

    /// The reading measured closest to `date`; `nil` without one within `tolerance`.
    public func metres(at date: Date) -> Double? {
        let index = firstIndex(notBefore: date)
        var best: Reading?
        for candidate in [index - 1, index] where readings.indices.contains(candidate) {
            let reading = readings[candidate]
            if let best, abs(best.date.timeIntervalSince(date)) <= abs(reading.date.timeIntervalSince(date)) { continue }
            best = reading
        }
        guard let best, abs(best.date.timeIntervalSince(date)) <= Self.tolerance else { return nil }
        return best.metres
    }

    private func firstIndex(notBefore date: Date) -> Int {
        var low = 0, high = readings.count
        while low < high {
            let middle = (low + high) / 2
            if readings[middle].date < date { low = middle + 1 } else { high = middle }
        }
        return low
    }
}
