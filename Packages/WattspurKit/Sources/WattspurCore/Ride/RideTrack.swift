import Foundation

/// The time series of a ride, searchable by distance, time and position, to couple
/// the charts and the map (B-062, TOUR-06): the spot under the mouse in one place
/// is looked up in the other two.
public struct RideTrack: Sendable, Equatable {
    /// One recorded moment with its values.
    public struct Fix: Sendable, Equatable {
        /// Seconds since the start of the time series.
        public var time: Double
        public var distanceKm: Double
        public var latitude: Double?
        public var longitude: Double?
        public var altitude: Double?
        public var speedKmh: Double?
        public var cadence: Double?
        public var power: Double?
    }

    /// Samples further than this from the asked time are no answer: a pause or a gap in between.
    public static let maxTimeDistance = 10.0

    private let fixes: [Fix]
    /// Indices into `fixes` of the samples that have a distance, in distance order.
    private let withDistance: [Int]
    /// Indices into `fixes` of the samples that have a position.
    private let withPosition: [Int]
    /// The samples that have a distance and an altitude, in distance order.
    private let elevation: [ElevationPoint]

    private struct ElevationPoint: Sendable, Equatable {
        var metres: Double
        var altitude: Double
    }

    public init(samples: [RideSample]) {
        var fixes: [Fix] = []
        var withDistance: [Int] = []
        var withPosition: [Int] = []
        var elevation: [ElevationPoint] = []
        var lastDistance = 0.0
        for sample in samples.sorted(by: { $0.time < $1.time }) {
            if let distance = sample.distance { lastDistance = distance }
            fixes.append(Fix(time: sample.time, distanceKm: lastDistance / 1000,
                             latitude: sample.latitude, longitude: sample.longitude,
                             altitude: sample.altitude, speedKmh: sample.speed.map { $0 * 3.6 },
                             cadence: sample.cadence.map(Double.init), power: sample.power.map(Double.init)))
            if sample.distance != nil { withDistance.append(fixes.count - 1) }
            if sample.distance != nil, let altitude = sample.altitude {
                elevation.append(ElevationPoint(metres: lastDistance, altitude: altitude))
            }
            if sample.latitude != nil && sample.longitude != nil { withPosition.append(fixes.count - 1) }
        }
        self.fixes = fixes
        self.withDistance = withDistance
        self.withPosition = withPosition
        self.elevation = elevation
    }

    public var isEmpty: Bool { fixes.isEmpty }

    /// The sample nearest to a distance; `nil` beyond the ends of the ride.
    public func fix(atDistanceKm km: Double) -> Fix? {
        guard let first = withDistance.first, let last = withDistance.last,
              km >= fixes[first].distanceKm - 0.05, km <= fixes[last].distanceKm + 0.05 else { return nil }
        let i = nearest(in: withDistance, to: km) { fixes[$0].distanceKm }
        return fixes[withDistance[i]]
    }

    /// The shortest stretch, in metres, that gives a grade; a shorter one is too noisy (B-200).
    public static let minGradeWindow = 30.0

    /// The grade in percent around a distance, over the stretch `window` metres either side
    /// (B-200): rise divided by run, with the altitude interpolated between the samples.
    /// GPS points lie a few metres apart and the altitude jitters by about a metre, so three
    /// neighbouring points would make the grade jump; a stretch of 100 m keeps it calm. Near
    /// the ends of the ride the stretch is cut on that side; if less than `minGradeWindow`
    /// is left, or there is no altitude, the answer is `nil`.
    public func grade(atDistanceKm km: Double, window: Double = 50) -> Double? {
        Self.grade(atMetres: km * 1000, window: window, in: elevation)
    }

    private static func grade(atMetres centre: Double, window: Double, in points: [ElevationPoint]) -> Double? {
        guard let first = points.first?.metres, let last = points.last?.metres else { return nil }
        guard centre >= first - 50, centre <= last + 50 else { return nil }
        let start = max(centre - window, first), end = min(centre + window, last)
        guard end - start >= minGradeWindow,
              let from = altitude(atMetres: start, in: points), let to = altitude(atMetres: end, in: points) else { return nil }
        return (to - from) / (end - start) * 100
    }

    /// Grades steeper than this (percent) are no road but a jump in the altitude, and are left out
    /// of the records (B-203). The steepest public roads reach about 35 %, a cargo bike hardly
    /// climbs more than 25 %.
    public static let maxPlausibleGrade = 30.0
    /// Number of neighbouring points the median filter looks at; a jump of up to two points in a
    /// row is smoothed away.
    static let medianWidth = 5

    /// The steepest climb and the steepest descent of the ride in percent (both positive), from the
    /// grade over the same stretch of 100 m as `grade(atDistanceKm:window:)`, taken every `step`
    /// metres. Only stretches with the whole window inside the ride count, so a short window at an
    /// end does not set a record. Without a barometer the altitude of a GPX file jumps by metres
    /// from one point to the next, so the altitude is first smoothed with a median over
    /// `medianWidth` points, and a grade above `maxPlausibleGrade` does not count (B-203); the
    /// grade shown in the chart (B-200) is not changed by this. `nil` without altitude, for a ride
    /// under 100 m, and for a direction the ride never goes.
    public func steepestGrades(step: Double = 10, window: Double = 50) -> (climb: Double?, descent: Double?) {
        let smooth = Self.median(of: elevation, width: Self.medianWidth)
        guard let first = smooth.first?.metres, let last = smooth.last?.metres, step > 0 else { return (nil, nil) }
        let start = first + window, end = last - window
        guard end >= start else { return (nil, nil) }
        var climb = 0.0, descent = 0.0
        for metres in stride(from: start, through: end, by: step) {
            guard let grade = Self.grade(atMetres: metres, window: window, in: smooth),
                  abs(grade) <= Self.maxPlausibleGrade else { continue }
            climb = max(climb, grade)
            descent = max(descent, -grade)
        }
        return (climb > 0 ? climb : nil, descent > 0 ? descent : nil)
    }

    /// The altitudes replaced by the median of the `width` points around each (fewer at the ends).
    private static func median(of points: [ElevationPoint], width: Int) -> [ElevationPoint] {
        let half = width / 2
        return points.indices.map { i in
            let around = points[max(0, i - half)...min(points.count - 1, i + half)].map(\.altitude).sorted()
            return ElevationPoint(metres: points[i].metres, altitude: around[around.count / 2])
        }
    }

    /// The altitude at a distance in metres, interpolated between the two points around it.
    private static func altitude(atMetres metres: Double, in points: [ElevationPoint]) -> Double? {
        guard !points.isEmpty else { return nil }
        var low = 0, high = points.count - 1
        while low < high {
            let mid = (low + high) / 2
            if points[mid].metres < metres { low = mid + 1 } else { high = mid }
        }
        let after = points[low]
        guard low > 0 else { return after.altitude }
        let before = points[low - 1]
        let span = after.metres - before.metres
        guard span > 0 else { return after.altitude }
        let share = (metres - before.metres) / span
        return before.altitude + (after.altitude - before.altitude) * share
    }

    /// The sample nearest to a time; `nil` inside a pause or gap and beyond the ends of the ride.
    public func fix(atTime seconds: Double) -> Fix? {
        guard !fixes.isEmpty else { return nil }
        let indices = Array(fixes.indices)
        let i = nearest(in: indices, to: seconds) { fixes[$0].time }
        return abs(fixes[i].time - seconds) <= Self.maxTimeDistance ? fixes[i] : nil
    }

    /// The sample with a position nearest to the given one, and how far away it is in metres.
    public func fix(nearestToLatitude latitude: Double, longitude: Double) -> (fix: Fix, metres: Double)? {
        let metresPerDegree = 111_320.0
        let cosine = cos(latitude * .pi / 180)
        var best: (index: Int, squared: Double)?
        for index in withPosition {
            guard let lat = fixes[index].latitude, let lon = fixes[index].longitude else { continue }
            let dy = (lat - latitude) * metresPerDegree
            let dx = (lon - longitude) * metresPerDegree * cosine
            let squared = dx * dx + dy * dy
            if best == nil || squared < best!.squared { best = (index, squared) }
        }
        return best.map { (fixes[$0.index], $0.squared.squareRoot()) }
    }

    /// Binary search for the entry whose key is closest to `target`; `indices` is sorted by that key.
    private func nearest(in indices: [Int], to target: Double, key: (Int) -> Double) -> Int {
        var low = 0, high = indices.count - 1
        while low < high {
            let mid = (low + high) / 2
            if key(indices[mid]) < target { low = mid + 1 } else { high = mid }
        }
        if low > 0, abs(key(indices[low - 1]) - target) <= abs(key(indices[low]) - target) { return low - 1 }
        return low
    }
}
