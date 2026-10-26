import Foundation

/// The best average power over a stretch of time, for the record "best 1-minute power"
/// (B-122, ADV-R3; a first step towards the power curve ADV-L1).
public enum PeakPower {
    /// Raise when the calculation changes; stored values with an older version are
    /// calculated again on the next launch.
    public static let version = 1
    /// The stretch of the record, in seconds.
    public static let window: TimeInterval = 60
    /// A larger gap between two records ends a run: nobody rode through it, so no stretch may
    /// span it (a pause, or the seam of a merged ride).
    static let maxGap: TimeInterval = 5

    /// The highest average power, in watts, that the rider held for `window` seconds without
    /// a break, or `nil` if no stretch that long has power values (a GPX file without power, a
    /// short ride). Each record counts until the next one, so uneven spacing is weighted by time.
    public static func bestAverage(of samples: [RideSample], window: TimeInterval = PeakPower.window) -> Int? {
        var best: Double?
        var times: [Double] = [], powers: [Double] = []
        func finishRun() {
            if let value = bestAverage(times: times, powers: powers, window: window) { best = max(best ?? value, value) }
            times.removeAll(keepingCapacity: true)
            powers.removeAll(keepingCapacity: true)
        }
        for sample in samples {
            guard let power = sample.power, sample.time.isFinite else { finishRun(); continue }
            if let last = times.last, sample.time - last > maxGap || sample.time < last { finishRun() }
            times.append(sample.time)
            powers.append(Double(max(0, power)))
        }
        finishRun()
        return best.map { Int($0.rounded()) }
    }

    /// The best average over `window` seconds inside one run of records without breaks.
    private static func bestAverage(times: [Double], powers: [Double], window: TimeInterval) -> Double? {
        guard let first = times.first, let last = times.last, last - first >= window else { return nil }
        // energy[k]: watt-seconds from the first record to record k, each power holding until the next.
        var energy = [Double](repeating: 0, count: times.count)
        for k in 1..<times.count { energy[k] = energy[k - 1] + powers[k - 1] * (times[k] - times[k - 1]) }
        var best = 0.0
        var end = 0 // the last record at or before the end of the stretch
        for start in times.indices {
            let stop = times[start] + window
            if stop > last { break }
            while end + 1 < times.count && times[end + 1] <= stop { end += 1 }
            let total = energy[end] - energy[start] + powers[end] * (stop - times[end])
            best = max(best, total / window)
        }
        return best
    }
}
