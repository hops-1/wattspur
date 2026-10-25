import Foundation

/// What the charts of a ride have on their x axis (TOUR-07).
public enum ChartAxis: String, CaseIterable, Sendable {
    /// Kilometres since start.
    case distance
    /// Ride time since start, pauses included; stretches without data stay empty.
    case time
}

/// One point of a chart over distance or time (TOUR-04, TOUR-07).
public struct ChartPoint: Sendable, Equatable, Identifiable {
    public var id: Int
    /// Kilometres since start.
    public var distanceKm: Double
    /// Seconds since start; only set for points over time.
    public var seconds: Double = 0
    /// Points over time: the stretch between two pauses or gaps; the line stops at the end of one.
    public var segment = 0
    public var altitude: Double?
    /// km/h
    public var speedKmh: Double?
    public var cadence: Double?
    public var power: Double?
}

/// A route point for the map.
public struct RoutePoint: Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Prepares the time series for display: charts get a fixed number of
/// distance bins (averaged), the map a thinned-out route.
public enum RideSeries {
    /// Averages the samples into `bins` equal distance slices. Empty slices repeat
    /// the previous value so the line has no holes.
    public static func chartPoints(from samples: [RideSample], bins: Int = 400) -> [ChartPoint] {
        let withDistance = samples.filter { $0.distance != nil }
        guard bins > 0, let total = withDistance.last?.distance, total > 0 else { return [] }

        struct Accumulator {
            var altitude = 0.0, altitudeCount = 0
            var speed = 0.0, speedCount = 0
            var cadence = 0.0, cadenceCount = 0
            var power = 0.0, powerCount = 0
        }
        var acc = [Accumulator](repeating: Accumulator(), count: bins)
        for sample in withDistance {
            let index = min(bins - 1, Int((sample.distance ?? 0) / total * Double(bins)))
            if let v = sample.altitude { acc[index].altitude += v; acc[index].altitudeCount += 1 }
            if let v = sample.speed { acc[index].speed += v * 3.6; acc[index].speedCount += 1 }
            if let v = sample.cadence { acc[index].cadence += Double(v); acc[index].cadenceCount += 1 }
            if let v = sample.power { acc[index].power += Double(v); acc[index].powerCount += 1 }
        }

        var points: [ChartPoint] = []
        points.reserveCapacity(bins)
        var last = ChartPoint(id: 0, distanceKm: 0)
        for (i, a) in acc.enumerated() {
            var point = last
            point.id = i
            point.distanceKm = (Double(i) + 0.5) / Double(bins) * total / 1000
            if a.altitudeCount > 0 { point.altitude = a.altitude / Double(a.altitudeCount) }
            if a.speedCount > 0 { point.speedKmh = a.speed / Double(a.speedCount) }
            if a.cadenceCount > 0 { point.cadence = a.cadence / Double(a.cadenceCount) }
            if a.powerCount > 0 { point.power = a.power / Double(a.powerCount) }
            points.append(point)
            last = point
        }
        return points
    }

    /// The shortest bin on the time axis, in seconds, so that no bin falls between two samples.
    static let minimumTimeBin = 4.0
    /// A break between two samples longer than this, and longer than two bins, is a pause or gap.
    static let minimumTimeGap = 20.0

    /// Like `chartPoints(from:bins:)`, but over the time since the start. Averaged into `bins` equal
    /// slices of time; slices inside a pause or a gap (merged rides, recording stopped) are left out and
    /// start a new `segment`, so the chart draws no line there.
    public static func chartPoints(from samples: [RideSample], axis: ChartAxis, bins: Int = 400) -> [ChartPoint] {
        switch axis {
        case .distance: return chartPoints(from: samples, bins: bins)
        case .time: return timePoints(from: samples, bins: bins)
        }
    }

    private static func timePoints(from samples: [RideSample], bins maxBins: Int) -> [ChartPoint] {
        let sorted = samples.sorted { $0.time < $1.time }
        guard let total = sorted.last?.time, total > 0, maxBins > 0 else { return [] }
        let bins = max(1, min(maxBins, Int(total / minimumTimeBin)))
        let width = total / Double(bins)
        let gapLimit = max(minimumTimeGap, 2 * width)

        struct Accumulator {
            var count = 0
            var altitude = 0.0, altitudeCount = 0
            var speed = 0.0, speedCount = 0
            var cadence = 0.0, cadenceCount = 0
            var power = 0.0, powerCount = 0
            var distance = 0.0, distanceCount = 0
        }
        var acc = [Accumulator](repeating: Accumulator(), count: bins)
        for sample in sorted {
            let index = min(bins - 1, Int(sample.time / width))
            acc[index].count += 1
            if let v = sample.altitude { acc[index].altitude += v; acc[index].altitudeCount += 1 }
            if let v = sample.speed { acc[index].speed += v * 3.6; acc[index].speedCount += 1 }
            if let v = sample.cadence { acc[index].cadence += Double(v); acc[index].cadenceCount += 1 }
            if let v = sample.power { acc[index].power += Double(v); acc[index].powerCount += 1 }
            if let v = sample.distance { acc[index].distance += v; acc[index].distanceCount += 1 }
        }

        var points: [ChartPoint] = []
        points.reserveCapacity(bins)
        var last = ChartPoint(id: 0, distanceKm: 0)
        var segment = 0
        var afterGap = false
        var next = 0   // index of the first sample after the current bin's centre
        for (i, a) in acc.enumerated() {
            let centre = (Double(i) + 0.5) * width
            if a.count == 0 {
                while next < sorted.count, sorted[next].time < centre { next += 1 }
                let before = next > 0 ? sorted[next - 1].time : 0
                let after = next < sorted.count ? sorted[next].time : total
                if after - before > gapLimit {
                    afterGap = true
                    continue
                }
            } else if afterGap {
                segment += 1
                afterGap = false
            }
            var point = last
            point.id = i
            point.seconds = centre
            point.segment = segment
            if a.altitudeCount > 0 { point.altitude = a.altitude / Double(a.altitudeCount) }
            if a.speedCount > 0 { point.speedKmh = a.speed / Double(a.speedCount) }
            if a.cadenceCount > 0 { point.cadence = a.cadence / Double(a.cadenceCount) }
            if a.powerCount > 0 { point.power = a.power / Double(a.powerCount) }
            if a.distanceCount > 0 { point.distanceKm = a.distance / Double(a.distanceCount) / 1000 }
            points.append(point)
            last = point
        }
        return points
    }

    /// The steepest climb of the ride as a fraction (0.08 = 8 %), measured over at
    /// least `window` metres so that noise in the altitude does not create spikes.
    /// `nil` without altitude and distance data or for rides shorter than the window.
    public static func steepestGradient(from samples: [RideSample], window: Double = 100) -> Double? {
        let points = samples.compactMap { s -> (distance: Double, altitude: Double)? in
            guard let d = s.distance, let a = s.altitude else { return nil }
            return (d, a)
        }
        var best: Double?
        var j = 0
        for i in points.indices {
            if j < i { j = i }
            while j < points.count, points[j].distance - points[i].distance < window { j += 1 }
            guard j < points.count else { break }
            let grade = (points[j].altitude - points[i].altitude) / (points[j].distance - points[i].distance)
            best = max(best ?? grade, grade)
        }
        return best
    }

    /// Route for the map, keeping about `maxPoints` points.
    public static func route(from samples: [RideSample], maxPoints: Int = 1500) -> [RoutePoint] {
        let all = samples.compactMap { s -> RoutePoint? in
            guard let lat = s.latitude, let lon = s.longitude else { return nil }
            return RoutePoint(latitude: lat, longitude: lon)
        }
        guard all.count > maxPoints, maxPoints > 1 else { return all }
        let step = Double(all.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).map { all[Int((Double($0) * step).rounded())] }
    }
}
