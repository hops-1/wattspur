import Foundation

/// Which way the recording map points with "direction of travel up" (B-280). The direction comes from
/// the GPS movement (`CLLocation.course`), not from the compass, which points anywhere with the
/// iPhone in a pocket. Standing still, or creeping along where the course jumps around, the map keeps
/// the direction it had.
public enum MapHeading {
    /// From about 7 km/h the course of the GPS is steady enough.
    public static let minimumSpeed = 2.0
    /// A course less certain than this is left out.
    public static let maximumCourseAccuracy = 45.0

    /// The new heading of the map in degrees (0 = north, clockwise), or `current` when this fix
    /// does not say reliably where the ride goes. Negative values mean "unknown", as in CoreLocation;
    /// an unknown accuracy of a known course is accepted (the simulator and some fixes give none).
    public static func next(current: Double?, course: Double, courseAccuracy: Double, speed: Double) -> Double? {
        guard course >= 0, speed >= minimumSpeed, courseAccuracy <= maximumCourseAccuracy else {
            return current
        }
        return course.truncatingRemainder(dividingBy: 360)
    }
}
