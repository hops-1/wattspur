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

    public init(samples: [RideSample]) {
        var fixes: [Fix] = []
        var withDistance: [Int] = []
        var withPosition: [Int] = []
        var lastDistance = 0.0
        for sample in samples.sorted(by: { $0.time < $1.time }) {
            if let distance = sample.distance { lastDistance = distance }
            fixes.append(Fix(time: sample.time, distanceKm: lastDistance / 1000,
                             latitude: sample.latitude, longitude: sample.longitude,
                             altitude: sample.altitude, speedKmh: sample.speed.map { $0 * 3.6 },
                             cadence: sample.cadence.map(Double.init), power: sample.power.map(Double.init)))
            if sample.distance != nil { withDistance.append(fixes.count - 1) }
            if sample.latitude != nil && sample.longitude != nil { withPosition.append(fixes.count - 1) }
        }
        self.fixes = fixes
        self.withDistance = withDistance
        self.withPosition = withPosition
    }

    public var isEmpty: Bool { fixes.isEmpty }

    /// The sample nearest to a distance; `nil` beyond the ends of the ride.
    public func fix(atDistanceKm km: Double) -> Fix? {
        guard let first = withDistance.first, let last = withDistance.last,
              km >= fixes[first].distanceKm - 0.05, km <= fixes[last].distanceKm + 0.05 else { return nil }
        let i = nearest(in: withDistance, to: km) { fixes[$0].distanceKm }
        return fixes[withDistance[i]]
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
