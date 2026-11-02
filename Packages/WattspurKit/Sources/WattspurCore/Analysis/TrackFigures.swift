import Foundation

/// The figures of a ride that come from its track and are calculated once, stored with the ride and
/// calculated again when `version` rises: the curviness (B-180) and the steepest climb and descent
/// (B-202, for the records).
public struct TrackFigures: Sendable, Equatable {
    /// Raise when one of the calculations changes.
    public static let version = 3

    /// Curvature per kilometre (`CurvatureAnalyzer`); `nil` without GPS or under a kilometre of track.
    public var curvaturePerKm: Double?
    /// Percent, positive; `nil` without altitude.
    public var steepestClimb: Double?
    public var steepestDescent: Double?

    public init(curvaturePerKm: Double? = nil, steepestClimb: Double? = nil, steepestDescent: Double? = nil) {
        self.curvaturePerKm = curvaturePerKm
        self.steepestClimb = steepestClimb
        self.steepestDescent = steepestDescent
    }

    public init(samples: [RideSample]) {
        let grades = RideTrack(samples: samples).steepestGrades()
        self.init(curvaturePerKm: CurvatureAnalyzer.analyze(samples).perKm,
                  steepestClimb: grades.climb, steepestDescent: grades.descent)
    }
}
