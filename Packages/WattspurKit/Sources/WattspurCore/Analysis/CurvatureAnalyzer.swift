import Foundation

/// How curvy a ride is, after the method of roadcurvature.com (B-180, V-13): the radius of
/// the circle through three points, the stretches sorted by it into tight, gentle and
/// straight, and the length of each weighted 2, 1 and 0. This is written from the published
/// description, not taken from its GPL code.
///
/// GPS points jitter by a few metres, and the circle through three jittering points on a
/// straight road is small, so the track is first brought to even steps of 10 m and smoothed
/// (`Method.standard`) before the radius is taken over 30 m on either side. On the roads of
/// roadcurvature.com themselves this finds about 45 % of their figure, because their
/// geometry has no noise to guard against and keeps every bend; the values of rides and of
/// roads are therefore not on one scale.
public enum CurvatureAnalyzer {
    /// Raise when the calculation changes; stored values with an older version are
    /// calculated again on the next launch.
    public static let version = 1

    /// Radii in metres: tighter than `tightRadius` is a tight curve, then up to
    /// `gentleRadius` a gentle one, wider is straight.
    public static let tightRadius = 30.0
    public static let gentleRadius = 175.0

    /// The distance between the points the track is resampled to, in metres.
    static let spacing = 10.0
    /// Samples closer than this to the last one count as standing still.
    static let minMove = 3.0
    /// A jump further than this, or a gap longer than `maxTimeGap` seconds, ends a run: nobody
    /// rode through it (a pause, the seam of a merged ride, lost GPS).
    static let maxJump = 100.0
    static let maxTimeGap = 30.0

    /// How the track is smoothed and over which stretch a radius is taken, both in metres.
    public struct Method: Sendable, Equatable {
        /// The width of the Gaussian smoothing, as its standard deviation.
        public var smoothing: Double
        /// The distance of the two outer points from the middle one.
        public var baseline: Double

        public init(smoothing: Double, baseline: Double) {
            self.smoothing = smoothing
            self.baseline = baseline
        }

        /// Wide enough that GPS noise of 3 m makes next to no curves on a straight road (smoothing of 10 m
        /// with 20 m: 580 per kilometre, 15 and 30: 130, 20 and 30: 18), at the price of blurring the tightest bends.
        public static let standard = Method(smoothing: 20, baseline: 30)

        /// Weights for the neighbours −h…h, summing to 1.
        var kernel: [Double] {
            let sigma = max(smoothing / CurvatureAnalyzer.spacing, 0.01)
            let half = Int((3 * sigma).rounded(.up))
            let raw = (-half...half).map { exp(-Double($0 * $0) / (2 * sigma * sigma)) }
            let sum = raw.reduce(0, +)
            return raw.map { $0 / sum }
        }

        var reach: Int { max(1, Int((baseline / CurvatureAnalyzer.spacing).rounded())) }
    }

    /// The kind of a stretch; the weight counts in the curvature.
    public enum Kind: Int, Sendable, Comparable, CaseIterable {
        case straight, gentle, tight

        public var weight: Double { Double(rawValue) }

        public static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }

        /// The kind of a radius in metres.
        public static func of(radius: Double) -> Kind {
            radius < CurvatureAnalyzer.tightRadius ? .tight : radius < CurvatureAnalyzer.gentleRadius ? .gentle : .straight
        }
    }

    /// A position on the track.
    public struct Point: Sendable, Equatable {
        public var latitude: Double
        public var longitude: Double
    }

    /// A piece of the track of one kind, for drawing it in a colour.
    public struct Piece: Sendable, Equatable {
        public var kind: Kind
        public var points: [Point]
    }

    public struct Result: Sendable, Equatable {
        /// The track in pieces of one kind each, in riding order.
        public var pieces: [Piece] = []
        /// Metres that count: the track without standstill, gaps and the ends of each run.
        public var length = 0.0
        public var tightLength = 0.0
        public var gentleLength = 0.0

        /// The sum of length × weight over the stretches that count.
        public var curvature: Double { 2 * tightLength + gentleLength }

        /// Curvature per kilometre; `nil` with less than a kilometre that counts.
        public var perKm: Double? { length >= 1000 ? curvature / length * 1000 : nil }

        /// The share of the length that is a tight curve, 0 to 1.
        public var tightShare: Double { length > 0 ? tightLength / length : 0 }
    }

    /// The curviness of a ride's track.
    public static func analyze(_ samples: [RideSample], method: Method = .standard) -> Result {
        var result = Result()
        let positioned = samples.compactMap { sample -> (time: Double, latitude: Double, longitude: Double)? in
            guard let latitude = sample.latitude, let longitude = sample.longitude,
                  latitude.isFinite, longitude.isFinite, sample.time.isFinite else { return nil }
            return (sample.time, latitude, longitude)
        }
        guard let first = positioned.first else { return result }
        let plane = Plane(latitude: first.latitude, longitude: first.longitude)

        var run: [(x: Double, y: Double)] = []
        var lastTime = first.time
        func finishRun() {
            analyze(run: run, plane: plane, method: method, into: &result)
            run.removeAll(keepingCapacity: true)
        }
        for sample in positioned {
            let p = plane.point(latitude: sample.latitude, longitude: sample.longitude)
            if let last = run.last {
                let distance = ((p.x - last.x) * (p.x - last.x) + (p.y - last.y) * (p.y - last.y)).squareRoot()
                if sample.time - lastTime > maxTimeGap || sample.time < lastTime || distance > maxJump {
                    finishRun()
                } else if distance < minMove {
                    lastTime = sample.time
                    continue
                }
            }
            run.append(p)
            lastTime = sample.time
        }
        finishRun()
        return result
    }

    /// One run without breaks: resampled, smoothed, then each point's radius.
    private static func analyze(run: [(x: Double, y: Double)], plane: Plane, method: Method, into result: inout Result) {
        let track = resample(run)
        let kernel = method.kernel
        let half = kernel.count / 2
        let reach = method.reach
        // The radius needs the smoothed points `reach` steps either side, and those need `half` more.
        let margin = half + reach
        guard track.count >= 2 * margin + 1 else { return }
        var smooth = track
        for i in half..<(track.count - half) {
            var x = 0.0, y = 0.0
            for (k, weight) in kernel.enumerated() {
                x += weight * track[i + k - half].x
                y += weight * track[i + k - half].y
            }
            smooth[i] = (x, y)
        }
        let evaluated = margin...(track.count - 1 - margin)
        var kinds: [Int: Kind] = [:]
        for i in evaluated {
            let kind = Kind.of(radius: circumradius(smooth[i - reach], smooth[i], smooth[i + reach]))
            kinds[i] = kind
            result.length += spacing
            switch kind {
            case .tight: result.tightLength += spacing
            case .gentle: result.gentleLength += spacing
            case .straight: break
            }
        }
        // Pieces: each step takes the tighter kind of its two ends.
        func point(_ i: Int) -> Point {
            let p = plane.coordinate(x: track[i].x, y: track[i].y)
            return Point(latitude: p.latitude, longitude: p.longitude)
        }
        var current: Piece?
        for i in evaluated.dropLast() {
            let kind = max(kinds[i] ?? .straight, kinds[i + 1] ?? .straight)
            if current?.kind == kind {
                current?.points.append(point(i + 1))
            } else {
                if let current { result.pieces.append(current) }
                current = Piece(kind: kind, points: [point(i), point(i + 1)])
            }
        }
        if let current { result.pieces.append(current) }
    }

    /// The track at even steps of `spacing` metres along it.
    private static func resample(_ run: [(x: Double, y: Double)]) -> [(x: Double, y: Double)] {
        guard run.count > 1 else { return run }
        var out = [run[0]]
        var next = spacing
        var travelled = 0.0
        for k in 1..<run.count {
            let a = run[k - 1], b = run[k]
            let length = ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
            while travelled + length >= next {
                let t = (next - travelled) / length
                out.append((a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t))
                next += spacing
            }
            travelled += length
        }
        return out
    }

    /// The radius of the circle through three points, in metres; infinite on a straight line.
    static func circumradius(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double), _ c: (x: Double, y: Double)) -> Double {
        func distance(_ p: (x: Double, y: Double), _ q: (x: Double, y: Double)) -> Double {
            ((p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y)).squareRoot()
        }
        let twiceArea = abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y))
        guard twiceArea > 1e-9 else { return .infinity }
        return distance(a, b) * distance(b, c) * distance(a, c) / (2 * twiceArea)
    }

    /// Metres east and north of a start point; precise enough for a ride.
    private struct Plane {
        let latitude: Double
        let longitude: Double
        private let metresPerDegree = 111_320.0

        init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }

        private var cosine: Double { cos(latitude * .pi / 180) }

        func point(latitude lat: Double, longitude lon: Double) -> (x: Double, y: Double) {
            ((lon - longitude) * metresPerDegree * cosine, (lat - latitude) * metresPerDegree)
        }

        func coordinate(x: Double, y: Double) -> (latitude: Double, longitude: Double) {
            (latitude + y / metresPerDegree, longitude + x / (metresPerDegree * cosine))
        }
    }
}

/// The words for how curvy a ride is, from its curvature per kilometre (B-181). Rides do not
/// share the scale of roadcurvature's roads, so the limits come from a library of 156 rides of
/// 10 km and more: median 202, 90 % below 251, the highest 373. Straight is the lower third,
/// very curvy only the top few per cent.
public enum Curviness: Sendable, Equatable {
    case straight, curvy, veryCurvy

    /// From this curvature per kilometre on a ride counts as curvy, and as very curvy.
    public static let curvyFrom = 190.0
    public static let veryCurvyFrom = 270.0
    /// Only rides of at least this length (metres) can hold the record and show the figure: on a
    /// short ride a few junctions weigh too much (a 3.9 km path of gentle waves scored 357).
    public static let minimumDistanceForRecord = 10_000.0

    public init(perKm: Double) {
        self = perKm >= Self.veryCurvyFrom ? .veryCurvy : perKm >= Self.curvyFrom ? .curvy : .straight
    }
}
