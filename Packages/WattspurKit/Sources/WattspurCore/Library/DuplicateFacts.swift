import Foundation

/// What the duplicate dialog puts side by side: a ride in the library and a new file that looks
/// like the same ride (B-143, B-144). `nil` stands for "not in this source".
public struct DuplicateFacts: Sendable, Equatable {
    public var source: RideSource?
    public var startDate: Date
    /// Metres; for a GPX the estimate from the track.
    public var distance: Double
    public var rideTime: TimeInterval
    public var ascent: Int?
    public var averagePower: Int?
    public var pointCount: Int
    /// `true` if the totals are estimated from a GPS track.
    public var estimated: Bool

    public init(source: RideSource?, startDate: Date, distance: Double, rideTime: TimeInterval, ascent: Int?,
                averagePower: Int?, pointCount: Int, estimated: Bool) {
        self.source = source
        self.startDate = startDate
        self.distance = distance
        self.rideTime = rideTime
        self.ascent = ascent
        self.averagePower = averagePower
        self.pointCount = pointCount
        self.estimated = estimated
    }

    public init(parsed: ParsedRide, source: RideSource?) {
        self.source = source
        startDate = parsed.startDate
        distance = parsed.summary.distance
        rideTime = parsed.summary.timerTime
        ascent = parsed.summary.totalAscent
        averagePower = parsed.summary.averagePower
        pointCount = parsed.samples.count
        estimated = parsed.summaryEstimated
    }
}
