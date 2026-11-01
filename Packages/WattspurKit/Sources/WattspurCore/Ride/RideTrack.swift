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
    /// Indices into `fixes` of the samples that have a distance and an altitude, in distance order.
    private let withElevation: [Int]

    public init(samples: [RideSample]) {
        var fixes: [Fix] = []
        var withDistance: [Int] = []
        var withPosition: [Int] = []
        var withElevation: [Int] = []
        var lastDistance = 0.0
        for sample in samples.sorted(by: { $0.time < $1.time }) {
            if let distance = sample.distance { lastDistance = distance }
            fixes.append(Fix(time: sample.time, distanceKm: lastDistance / 1000,
                             latitude: sample.latitude, longitude: sample.longitude,
                             altitude: sample.altitude, speedKmh: sample.speed.map { $0 * 3.6 },
                             cadence: sample.cadence.map(Double.init), power: sample.power.map(Double.init)))
            if sample.distance != nil { withDistance.append(fixes.count - 1) }
            if sample.distance != nil && sample.altitude != nil { withElevation.append(fixes.count - 1) }
            if sample.latitude != nil && sample.longitude != nil { withPosition.append(fixes.count - 1) }
        }
        self.fixes = fixes
        self.withDistance = withDistance
        self.withPosition = withPosition
        self.withElevation = withElevation
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
        guard let first = withElevation.first, let last = withElevation.last else { return nil }
        let firstMetres = fixes[first].distanceKm * 1000, lastMetres = fixes[last].distanceKm * 1000
        let centre = km * 1000
        guard centre >= firstMetres - 50, centre <= lastMetres + 50 else { return nil }
        let start = max(centre - window, firstMetres), end = min(centre + window, lastMetres)
        guard end - start >= Self.minGradeWindow,
              let from = altitude(atMetres: start), let to = altitude(atMetres: end) else { return nil }
        return (to - from) / (end - start) * 100
    }

    /// The steepest climb and the steepest descent of the ride in percent (both positive), from the
    /// grade over the same stretch of 100 m as `grade(atDistanceKm:window:)`, taken every `step`
    /// metres. Only stretches with the whole window inside the ride count, so a short window at an
    /// end does not set a record. `nil` without altitude, for a ride under 100 m, and for a
    /// direction the ride never goes.
    public func steepestGrades(step: Double = 10, window: Double = 50) -> (climb: Double?, descent: Double?) {
        guard let first = withElevation.first, let last = withElevation.last, step > 0 else { return (nil, nil) }
        let start = fixes[first].distanceKm * 1000 + window, end = fixes[last].distanceKm * 1000 - window
        guard end >= start else { return (nil, nil) }
        var climb = 0.0, descent = 0.0
        for metres in stride(from: start, through: end, by: step) {
            guard let grade = self.grade(atDistanceKm: metres / 1000, window: window) else { continue }
            climb = max(climb, grade)
            descent = max(descent, -grade)
        }
        return (climb > 0 ? climb : nil, descent > 0 ? descent : nil)
    }

    /// The altitude at a distance in metres, interpolated between the two samples around it.
    private func altitude(atMetres metres: Double) -> Double? {
        var low = 0, high = withElevation.count - 1
        while low < high {
            let mid = (low + high) / 2
            if fixes[withElevation[mid]].distanceKm * 1000 < metres { low = mid + 1 } else { high = mid }
        }
        let after = fixes[withElevation[low]]
        guard let afterAltitude = after.altitude else { return nil }
        guard low > 0 else { return afterAltitude }
        let before = fixes[withElevation[low - 1]]
        guard let beforeAltitude = before.altitude else { return afterAltitude }
        let span = (after.distanceKm - before.distanceKm) * 1000
        guard span > 0 else { return afterAltitude }
        let share = (metres - before.distanceKm * 1000) / span
        return beforeAltitude + (afterAltitude - beforeAltitude) * share
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
