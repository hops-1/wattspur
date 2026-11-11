import Foundation

/// A gap in a track: two positions one after the other that lie so far apart that nobody rode
/// between them, e.g. a train ride without recording (B-309, issue #164). Maps draw no line
/// across a gap, the GPX export starts a new segment there, and the distance does not grow.
public enum TrackGap {
    /// Two positions further apart than this are a gap, in metres (the tester's proposal).
    /// A ride logs a position every second or every few metres, so no real step comes close.
    public static let distance = 2_000.0

    /// `true` when the step between the two positions is a gap.
    public static func isGap(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Bool {
        GPXGeo.distance(lat1, lon1, lat2, lon2) > distance
    }

    public static func isGap(_ a: RoutePoint, _ b: RoutePoint) -> Bool {
        isGap(a.latitude, a.longitude, b.latitude, b.longitude)
    }

    /// Splits the points at every gap; points without a position stay with the stretch they are in.
    /// No gap gives the points back as one stretch, and no points give no stretch.
    public static func split<Point>(_ points: [Point], position: (Point) -> (latitude: Double, longitude: Double)?) -> [[Point]] {
        var stretches: [[Point]] = []
        var current: [Point] = []
        var last: (latitude: Double, longitude: Double)?
        for point in points {
            if let here = position(point) {
                if let last, isGap(last.latitude, last.longitude, here.latitude, here.longitude), !current.isEmpty {
                    stretches.append(current)
                    current = []
                }
                last = here
            }
            current.append(point)
        }
        if !current.isEmpty { stretches.append(current) }
        return stretches
    }

    public static func split(_ points: [RoutePoint]) -> [[RoutePoint]] {
        split(points) { ($0.latitude, $0.longitude) }
    }

    public static func split(_ samples: [RideSample]) -> [[RideSample]] {
        split(samples) { sample in
            guard let latitude = sample.latitude, let longitude = sample.longitude else { return nil }
            return (latitude, longitude)
        }
    }
}
