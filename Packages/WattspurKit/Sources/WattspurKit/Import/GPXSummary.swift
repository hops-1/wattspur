import Foundation

/// The numbers behind the totals of a GPX ride (B-142). The start values were confirmed on
/// 25.10.2026; the height threshold is meant to become a setting later (SET-04: 1 / 3 / 5 m).
public struct GPXSummaryParameters: Sendable, Equatable {
    /// Below this speed in m/s over the window the rider stands still: the time does not count as ride time.
    public var standstillSpeed = 0.8
    /// Half width in seconds of the window around a step that decides about standing still. The speed
    /// is the straight line between the window's ends, so GPS jitter while standing adds nothing.
    public var standstillWindow: TimeInterval = 5
    /// Heights are smoothed with the median of this many points (odd) before they are counted.
    public var altitudeMedianPoints = 5
    /// A change of height counts as ascent or descent once it exceeds the last counted height by this many metres.
    public var ascentThreshold = 3.0
    /// The maximum speed is taken over a stretch of at least this many seconds, not from single points.
    public var maxSpeedWindow: TimeInterval = 5

    public init() {}

    public static let standard = GPXSummaryParameters()
}

extension GPXTrack {
    /// Totals computed from the track (Requirements 3.2). Estimates: a Bosch FIT delivers its own.
    public struct Totals: Sendable, Equatable {
        /// Time on the move: steps between points, without pauses (gaps) and without standing still.
        public var movingTime: TimeInterval
        /// Time between points spent standing still, without the pauses.
        public var standingTime: TimeInterval
        /// Metres along the track, without the stretches between parts. Steps while standing still
        /// are left out, so GPS jitter at a red light does not add distance.
        public var distance: Double
        /// Metres per second, over the shortest stretch of `maxSpeedWindow` seconds or more.
        public var maxSpeed: Double?
        /// Whole metres from the smoothed heights; `nil` if the track has no heights.
        public var ascent: Int?
        public var descent: Int?
    }

    public func totals(_ parameters: GPXSummaryParameters = .standard) -> Totals {
        var moving = 0.0, standing = 0.0, distance = 0.0
        var maxSpeed: Double?
        var ascent = 0.0, descent = 0.0
        var hasHeights = false

        for part in parts {
            let steps = Self.steps(of: part.samples, parameters)
            for step in steps {
                if step.standing { standing += step.seconds } else { moving += step.seconds; distance += step.metres }
            }
            if let top = Self.maxSpeed(of: part.samples, window: parameters.maxSpeedWindow) {
                maxSpeed = Swift.max(maxSpeed ?? 0, top)
            }
            let heights = part.samples.compactMap(\.altitude)
            if heights.count >= 2 {
                hasHeights = true
                let counted = Self.climb(Self.median(heights, points: parameters.altitudeMedianPoints), threshold: parameters.ascentThreshold)
                ascent += counted.up
                descent += counted.down
            }
        }
        return Totals(movingTime: moving, standingTime: standing, distance: distance, maxSpeed: maxSpeed,
                      ascent: hasHeights ? Int(ascent.rounded()) : nil,
                      descent: hasHeights ? Int(descent.rounded()) : nil)
    }

    private struct Step {
        var seconds: Double
        var metres: Double
        var standing: Bool
    }

    /// Straight-line metres between two samples with a position.
    private static func metres(_ a: RideSample, _ b: RideSample) -> Double {
        guard let lat1 = a.latitude, let lon1 = a.longitude, let lat2 = b.latitude, let lon2 = b.longitude else { return 0 }
        return GPXGeo.distance(lat1, lon1, lat2, lon2)
    }

    private static func steps(of samples: [RideSample], _ parameters: GPXSummaryParameters) -> [Step] {
        guard samples.count >= 2 else { return [] }
        let window = parameters.standstillWindow
        var steps: [Step] = []
        steps.reserveCapacity(samples.count - 1)
        var lo = 0, hi = 1
        for i in 0..<(samples.count - 1) {
            let t0 = samples[i].time, t1 = samples[i + 1].time
            while samples[lo].time < t0 - window { lo += 1 }
            if hi < i + 1 { hi = i + 1 }
            while hi + 1 < samples.count, samples[hi + 1].time <= t1 + window { hi += 1 }
            let span = samples[hi].time - samples[lo].time
            let speed = span > 0 ? metres(samples[lo], samples[hi]) / span : 0
            steps.append(Step(seconds: t1 - t0, metres: metres(samples[i], samples[i + 1]),
                              standing: span > 0 && speed < parameters.standstillSpeed))
        }
        return steps
    }

    private static func maxSpeed(of samples: [RideSample], window: TimeInterval) -> Double? {
        guard let first = samples.first, let last = samples.last, samples.count >= 2 else { return nil }
        // A part shorter than the window has only itself to measure.
        if last.time - first.time < window {
            let span = last.time - first.time
            return span > 0 ? metres(first, last) / span : nil
        }
        var best: Double?
        var k = 0
        for j in 0..<(samples.count - 1) {
            k = Swift.max(k, j + 1)
            while k < samples.count, samples[k].time - samples[j].time < window { k += 1 }
            if k >= samples.count { break }
            best = Swift.max(best ?? 0, metres(samples[j], samples[k]) / (samples[k].time - samples[j].time))
        }
        return best
    }

    /// Median of up to `points` neighbours; the window shrinks at both ends.
    private static func median(_ values: [Double], points: Int) -> [Double] {
        let half = Swift.max(0, points / 2)
        guard half > 0, values.count > 2 else { return values }
        return values.indices.map { i in
            let slice = values[Swift.max(0, i - half)...Swift.min(values.count - 1, i + half)].sorted()
            return slice[slice.count / 2]
        }
    }

    /// Ascent and descent: a change counts once it exceeds the last counted height by `threshold`.
    private static func climb(_ heights: [Double], threshold: Double) -> (up: Double, down: Double) {
        guard var reference = heights.first else { return (0, 0) }
        var up = 0.0, down = 0.0
        for height in heights.dropFirst() {
            if height - reference >= threshold {
                up += height - reference
                reference = height
            } else if reference - height >= threshold {
                down += reference - height
                reference = height
            }
        }
        return (up, down)
    }
}

/// Distances on the globe, shared by the GPX code.
enum GPXGeo {
    /// Great-circle distance in metres.
    static func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let radius = 6_371_000.0
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dLat = p2 - p1
        let dLon = (lon2 - lon1) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(p1) * cos(p2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, h.squareRoot()))
    }
}
