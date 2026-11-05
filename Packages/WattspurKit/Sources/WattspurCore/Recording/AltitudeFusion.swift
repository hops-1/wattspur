import Foundation

/// The height while recording on the iPhone (B-235): the barometer for the shape, GPS for the level.
///
/// The barometer (`CMAltimeter`, relative height since the start) measures changes of a metre or
/// less with little noise, but it knows no absolute height, and the weather moves it slowly (about
/// 8 m per hPa; a front can bring 1 hPa an hour). The GPS height has the right level but jumps by
/// metres from second to second. So the barometer gives the height, and an offset to the GPS height
/// lifts it to the right level: at first the median of the first good GPS heights, then corrected
/// slowly towards the GPS height with a time constant of `timeConstant`, which takes out the weather
/// without letting the GPS noise through. Without a barometer (none, or motion access denied) the
/// GPS height is used as before.
public struct AltitudeFusion: Sendable, Equatable {
    /// GPS heights less accurate than this do not move the offset.
    public static let maxVerticalAccuracy = 15.0
    /// The first offset is the median of this many good GPS heights.
    public static let anchorCount = 5
    /// Seconds over which the offset follows the GPS height: long against GPS noise, short against weather.
    public static let timeConstant: TimeInterval = 300

    private var anchor: [Double] = []
    /// GPS height minus barometer height; `nil` until the first good GPS height.
    public private(set) var offset: Double?
    private var lastCorrection: Date?

    public init() {}

    /// The height for one GPS position, in metres above sea level; `nil` without any height.
    /// - Parameters:
    ///   - gps: the GPS height, `nil` without a valid vertical position.
    ///   - verticalAccuracy: its accuracy in metres (negative means invalid).
    ///   - barometer: the barometer's height since its start, `nil` without one or when it is stale.
    public mutating func altitude(gps: Double?, verticalAccuracy: Double, barometer: Double?, at date: Date) -> Double? {
        guard let barometer else { return gps }
        if let gps, verticalAccuracy > 0, verticalAccuracy <= Self.maxVerticalAccuracy {
            let sample = gps - barometer
            if anchor.count < Self.anchorCount {
                anchor.append(sample)
                offset = Self.median(anchor)
            } else if let current = offset, let last = lastCorrection {
                let weight = min(1, max(0, date.timeIntervalSince(last)) / Self.timeConstant)
                offset = current + weight * (sample - current)
            }
            lastCorrection = date
        }
        guard let offset else { return gps }
        return barometer + offset
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
