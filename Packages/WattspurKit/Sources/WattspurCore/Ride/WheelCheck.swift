import Foundation

/// Compares the distance of the wheel sensor with the one from GPS (B-237).
///
/// Bosch measures distance and speed at the wheel; a wrong wheel circumference in the
/// Flow app makes both too high or too low. A FIT from Bosch Flow has the wheel distance
/// and the GPS track of the phone, so Wattspur can see the difference without a Bosch
/// account. Only a hint: the values of the rides stay as Bosch delivered them.
public enum WheelCheck {
    /// Metres of the good sections of one or more rides.
    public struct Sum: Sendable, Equatable {
        public var wheel: Double
        public var gps: Double

        public init(wheel: Double = 0, gps: Double = 0) {
            self.wheel = wheel
            self.gps = gps
        }

        public static func + (a: Sum, b: Sum) -> Sum { Sum(wheel: a.wheel + b.wheel, gps: a.gps + b.gps) }
    }

    /// From this difference on, the profile of the bike shows the hint.
    public static let threshold = 0.02
    /// Enough data for a mean: at least this many rides with at least this much good GPS.
    public static let minimumRides = 3
    public static let minimumRideGPS = 2_000.0
    public static let minimumGPS = 20_000.0

    /// Only samples with a GPS point and a wheel distance count. A phone does not deliver its
    /// points exactly once a second: some samples have none, and the steps alternate between
    /// short and long. So the track is cut into sections of at least `section` seconds, and
    /// the GPS distance of a section is the sum of its steps. A section counts only without a
    /// gap over 3 s, faster than 3 m/s (slow GPS wanders), and with both distances within
    /// 30 % of each other (no GPS jumps).
    public static let section: TimeInterval = 10
    static let maximumGap: TimeInterval = 3
    static let minimumSpeed = 3.0
    static let maximumSectionDifference = 0.3

    private struct Fix {
        var time: TimeInterval, latitude: Double, longitude: Double, distance: Double
    }

    /// The good sections of one ride.
    public static func measure(_ samples: [RideSample], section: TimeInterval = section) -> Sum {
        var sum = Sum()
        var start: Fix?
        var previous: Fix?
        var gps = 0.0
        for sample in samples {
            guard let latitude = sample.latitude, let longitude = sample.longitude, let distance = sample.distance else { continue }
            let fix = Fix(time: sample.time, latitude: latitude, longitude: longitude, distance: distance)
            defer { previous = fix }
            guard let before = previous, let first = start, fix.time - before.time <= maximumGap else {
                start = fix
                gps = 0
                continue
            }
            gps += GPXGeo.distance(before.latitude, before.longitude, fix.latitude, fix.longitude)
            let dt = fix.time - first.time
            guard dt >= section else { continue }
            let wheel = fix.distance - first.distance
            if wheel >= minimumSpeed * dt, abs(gps / wheel - 1) <= maximumSectionDifference {
                sum.wheel += wheel
                sum.gps += gps
            }
            start = fix
            gps = 0
        }
        return sum
    }

    /// How much the wheel measures more (positive) or less than GPS, e.g. 0.03 for 3 %, over
    /// the rides of one bike; `nil` without enough data.
    public static func deviation(_ rides: [Sum]) -> Double? {
        let usable = rides.filter { $0.gps >= minimumRideGPS }
        guard usable.count >= minimumRides else { return nil }
        let total = usable.reduce(Sum(), +)
        guard total.gps >= minimumGPS else { return nil }
        return total.wheel / total.gps - 1
    }

    /// The difference if it is large enough for the hint; `nil` otherwise.
    public static func hint(_ rides: [Sum]) -> Double? {
        deviation(rides).flatMap { abs($0) >= threshold ? $0 : nil }
    }
}
