import Foundation

/// Where the parts of one ride lie on its time axis, for a merged ride (`RideMerge`) and for a GPX
/// file with several parts (`GPXTrack`) alike (R-24).
///
/// A pause on the same day keeps its length: a part that starts on the day the previous one ended
/// lies as far after the previous part's start as it really does. A part on a later day follows the
/// previous one directly, so a tour over several days has no gap of a night. The distance is always
/// measured from the previous part, never from the first (R-17, R-18): day 1 at 10:00, day 2 at
/// 10:00 and 14:00 puts the last part 4 hours after the second, not a day later.
public enum PartTimeline {
    /// The start of each part on the time axis, in seconds; `starts` and `durations` in time order.
    public static func offsets(starts: [Date], durations: [TimeInterval], calendar: Calendar) -> [TimeInterval] {
        precondition(starts.count == durations.count)
        var result: [TimeInterval] = []
        result.reserveCapacity(starts.count)
        for index in starts.indices {
            guard index > 0 else {
                result.append(0)
                continue
            }
            let previousOffset = result[index - 1]
            let previousStart = starts[index - 1]
            let previousEnd = previousStart.addingTimeInterval(durations[index - 1])
            if calendar.isDate(previousEnd, inSameDayAs: starts[index]) {
                result.append(previousOffset + starts[index].timeIntervalSince(previousStart))
            } else {
                result.append(previousOffset + durations[index - 1])
            }
        }
        return result
    }
}
