import Foundation

/// The height while recording on the iPhone (B-235): the barometer for the shape, GPS for the level.
///
/// The barometer (`CMAltimeter`, relative height since the start) measures changes of a metre or
/// less with little noise, but it knows no absolute height, and the weather moves it slowly (about
/// 8 m per hPa; a front can bring 1 hPa an hour). The GPS height has the right level but jumps by
/// metres from second to second. So the barometer gives the height, and an offset to the GPS height
/// lifts it to the right level: the median of the first good GPS heights, then corrected slowly
/// towards the GPS height with a time constant of `timeConstant`, which takes out the weather without
/// letting the GPS noise through. Until that first level is found there is no height, so the first
/// seconds do not jump by metres and count as ascent (seen at a standstill on 5.11.2026). If no GPS
/// height is that good for `anchorTimeout`, the best of the rougher ones give the level (R-19). Without
/// a barometer (none, or motion access denied) the GPS height is used as before.
public struct AltitudeFusion: Sendable, Equatable {
    /// GPS heights less accurate than this do not move the offset.
    public static let maxVerticalAccuracy = 15.0
    /// The first offset is the median of this many good GPS heights.
    public static let anchorCount = 5
    /// Seconds after the first good GPS height when fewer good ones are enough for the first offset.
    public static let anchorTimeout: TimeInterval = 20
    /// Seconds over which the offset follows the GPS height: long against GPS noise, short against weather.
    public static let timeConstant: TimeInterval = 300
    /// Seconds at the start to wait for the first barometer reading instead of taking the GPS height.
    public static let barometerWait: TimeInterval = 10
    /// Seconds a stale barometer keeps its last height; after that there is no height until it is back,
    /// rather than a flat line that is not true.
    public static let barometerHold: TimeInterval = 60

    /// Set when the iPhone has a barometer that may be used: then the first seconds wait for it
    /// rather than start with a GPS height that the barometer height would jump away from.
    public var waitsForBarometer = false
    private var firstDate: Date?
    private var sawBarometer = false

    private var anchor: [Double] = []
    private var anchorStart: Date?
    /// GPS heights of any accuracy with their accuracy, for when no good one comes (R-19).
    private var rough: [RoughHeight] = []
    private struct RoughHeight: Sendable, Equatable {
        var sample: Double
        var accuracy: Double
    }
    private var roughStart: Date?
    /// The last barometer height, held while the barometer is briefly stale (R-20).
    private var lastBarometer: Double?
    private var lastBarometerDate: Date?
    /// GPS height minus barometer height; `nil` until the first good GPS height.
    public private(set) var offset: Double?
    private var lastCorrection: Date?

    public init() {}

    /// The height for one GPS position, in metres above sea level; `nil` without any height, and with
    /// a barometer until the first offset is found.
    /// - Parameters:
    ///   - gps: the GPS height, `nil` without a valid vertical position.
    ///   - verticalAccuracy: its accuracy in metres (negative means invalid).
    ///   - barometer: the barometer's height since its start, `nil` without one or when it is stale.
    public mutating func altitude(gps: Double?, verticalAccuracy: Double, barometer: Double?, at date: Date) -> Double? {
        if firstDate == nil { firstDate = date }
        guard let current = barometer else {
            if waitsForBarometer, !sawBarometer, let first = firstDate,
               date.timeIntervalSince(first) < Self.barometerWait {
                return nil
            }
            // A barometer that is briefly stale keeps its last height: switching to the raw GPS
            // height and back would jump by metres and count as ascent (R-20).
            if sawBarometer {
                guard let held = lastBarometer, let since = lastBarometerDate,
                      date.timeIntervalSince(since) <= Self.barometerHold else { return nil }
                return offset.map { held + $0 }
            }
            return gps
        }
        let barometer = current
        sawBarometer = true
        lastBarometer = barometer
        lastBarometerDate = date
        if let gps, verticalAccuracy > 0, verticalAccuracy <= Self.maxVerticalAccuracy {
            let sample = gps - barometer
            if let current = offset {
                let weight = lastCorrection.map { min(1, max(0, date.timeIntervalSince($0)) / Self.timeConstant) } ?? 0
                offset = current + weight * (sample - current)
            } else {
                anchor.append(sample)
                if anchorStart == nil { anchorStart = date }
            }
            lastCorrection = date
        } else if let gps, verticalAccuracy > 0, offset == nil {
            rough.append(RoughHeight(sample: gps - barometer, accuracy: verticalAccuracy))
            if roughStart == nil { roughStart = date }
        }
        if offset == nil, let start = anchorStart,
           anchor.count >= Self.anchorCount || date.timeIntervalSince(start) >= Self.anchorTimeout {
            offset = Self.median(anchor)
        }
        // No good GPS height for a while (town, forest: often 16 to 30 m): the most accurate of the
        // rough ones give the level, so the ride is not without height altogether (R-19). Good ones
        // that come later move it slowly, as always.
        if offset == nil, anchorStart == nil, let start = roughStart, date.timeIntervalSince(start) >= Self.anchorTimeout {
            let best = rough.sorted { $0.accuracy < $1.accuracy }.prefix(Self.anchorCount).map(\.sample)
            offset = Self.median(Array(best))
            lastCorrection = date
        }
        return offset.map { barometer + $0 }
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
