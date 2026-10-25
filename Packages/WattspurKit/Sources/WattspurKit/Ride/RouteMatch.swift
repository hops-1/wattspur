import Foundation

/// Does a second recording follow the same route? Used to confirm that two files are the same
/// ride (B-143, IMP-04): start and distance alone would also match two people on one tour.
///
/// Both simplified routes (`OverviewRoute`, B-104) are laid out as points every `step` metres, and
/// each point gets its distance to the other route. The routes match if, in both directions, the
/// median is at most `maxMedian` and 95 % of the points are within `maxPercentile95` metres.
/// A recording that stops early fails (the missing part is far from the other route), as do two
/// different rides in the same area. Measured on the pairs in `Fixtures/GPX` (SPIKE-GPX-FORMATE.md).
public enum RouteMatch {
    /// Spacing of the points laid along a route, in metres.
    public static let step = 50.0
    public static let maxMedian = 25.0
    public static let maxPercentile95 = 60.0

    /// How far the routes lie apart, the worse of the two directions.
    public struct Distances: Sendable, Equatable {
        public var median: Double
        public var percentile95: Double
    }

    /// `nil` if either route has no points.
    public static func distances(_ a: OverviewRoute, _ b: OverviewRoute) -> Distances? {
        guard let origin = a.segments.first?.first ?? b.segments.first?.first,
              !a.isEmpty, !b.isEmpty else { return nil }
        let projection = Projection(origin: origin)
        let lineA = a.segments.map { $0.map(projection.point) }
        let lineB = b.segments.map { $0.map(projection.point) }
        let ab = distances(from: resample(lineA), to: lineB)
        let ba = distances(from: resample(lineB), to: lineA)
        return Distances(median: max(ab.median, ba.median), percentile95: max(ab.percentile95, ba.percentile95))
    }

    public static func matches(_ a: OverviewRoute, _ b: OverviewRoute) -> Bool {
        guard let d = distances(a, b) else { return false }
        return d.median <= maxMedian && d.percentile95 <= maxPercentile95
    }

    // MARK: - Geometry

    private struct P { var x: Double; var y: Double }

    /// Flat metres around a start point; good enough for the few kilometres of a ride.
    private struct Projection {
        let lat0: Double, lon0: Double, cosLat: Double
        init(origin: RoutePoint) {
            lat0 = origin.latitude
            lon0 = origin.longitude
            cosLat = cos(origin.latitude * .pi / 180)
        }
        func point(_ p: RoutePoint) -> P {
            P(x: (p.longitude - lon0) * cosLat * 111_320, y: (p.latitude - lat0) * 110_540)
        }
    }

    /// Points every `step` metres along each segment, including its ends.
    private static func resample(_ segments: [[P]]) -> [P] {
        var out: [P] = []
        for segment in segments {
            guard var previous = segment.first else { continue }
            out.append(previous)
            var carried = 0.0 // metres since the last point
            for next in segment.dropFirst() {
                let length = hypot(next.x - previous.x, next.y - previous.y)
                var at = step - carried
                while at <= length {
                    let f = length > 0 ? at / length : 0
                    out.append(P(x: previous.x + (next.x - previous.x) * f, y: previous.y + (next.y - previous.y) * f))
                    at += step
                }
                carried = length - (at - step)
                previous = next
            }
            if let last = segment.last, let end = out.last, hypot(end.x - last.x, end.y - last.y) > 1 { out.append(last) }
        }
        return out
    }

    private static func distances(from points: [P], to segments: [[P]]) -> Distances {
        var found: [Double] = []
        found.reserveCapacity(points.count)
        for p in points {
            var best = Double.infinity
            for segment in segments {
                if segment.count == 1 {
                    best = min(best, hypot(p.x - segment[0].x, p.y - segment[0].y))
                    continue
                }
                for i in 0..<(segment.count - 1) {
                    best = min(best, distance(p, segment[i], segment[i + 1]))
                }
            }
            found.append(best)
        }
        found.sort()
        guard !found.isEmpty else { return Distances(median: .infinity, percentile95: .infinity) }
        return Distances(median: found[found.count / 2], percentile95: found[Int(Double(found.count - 1) * 0.95)])
    }

    private static func distance(_ p: P, _ a: P, _ b: P) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

/// The length of the GPS path in a time series, the same way for a Bosch FIT and a GPX track.
/// The FIT session's own distance comes from the wheel sensor and is about 5 % longer (V-11),
/// so ride and file are compared by their GPS paths.
public enum GPSPath {
    /// Steps over a gap this long are no riding (a pause), like in the GPX import.
    public static let maxGap: TimeInterval = 30
    /// Steps faster than this are GPS jumps, in m/s.
    public static let maxSpeed = 150.0 / 3.6

    /// Metres along the positions, without pauses, jumps and the seams of merged parts.
    public static func length(of samples: [RideSample]) -> Double {
        var total = 0.0
        var previous: RideSample?
        for sample in samples where sample.latitude != nil && sample.longitude != nil {
            defer { previous = sample }
            guard let last = previous, let lat1 = last.latitude, let lon1 = last.longitude,
                  let lat2 = sample.latitude, let lon2 = sample.longitude else { continue }
            let dt = sample.time - last.time
            guard dt > 0, dt < maxGap else { continue }
            let step = GPXGeo.distance(lat1, lon1, lat2, lon2)
            if step / dt <= maxSpeed { total += step }
        }
        return total
    }
}
