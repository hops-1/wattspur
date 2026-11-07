import Foundation

/// The figures of a ride from the motion sensors of the iPhone (B-246, B-247): the strongest lean
/// to either side, the strongest speeding up and braking, and the best time from a standstill to
/// 100 km/h (motorcycle) or 25 km/h (bicycle). Only for rides whose samples have a lean angle
/// (recordings of the iPhone app from 0.5.1 on, B-245).
public struct RideMotion: Sendable, Equatable {
    /// Degrees, both positive.
    public var maxLeanLeft: Double
    public var maxLeanRight: Double
    /// In g, both positive; `nil` without values.
    public var strongestAcceleration: Double?
    public var strongestBraking: Double?
    /// The best run from a standstill to `Sprint.target`; `nil` if the ride has none.
    public var sprint: Sprint?
    /// The share of the distance on an uneven or rough surface (B-248), 0…1; `nil` without values.
    public var roughShare: Double?

    public struct Sprint: Sendable, Equatable {
        /// km/h: 100 for a motorcycle, 25 for a bicycle.
        public var targetKmh: Double
        public var seconds: Double
    }

    /// Slower than this is standing still, in km/h.
    public static let standstillKmh = 3.0
    /// A run from a standstill to the target that takes longer is not a sprint.
    public static let maxSprintSeconds = 30.0
    /// Samples further apart break a run (a pause, a gap in the GPS).
    static let maxSampleGap = 5.0

    /// The target of the sprint: 100 km/h on a motorcycle, 25 km/h on a bicycle.
    public static func sprintTarget(motorized: Bool) -> Double { motorized ? 100 : 25 }

    /// `nil` if no sample has a lean angle.
    public init?(samples: [RideSample], motorized: Bool) {
        let leans = samples.compactMap(\.lean)
        guard !leans.isEmpty else { return nil }
        maxLeanLeft = max(leans.max() ?? 0, 0)
        maxLeanRight = max(-(leans.min() ?? 0), 0)
        let accelerations = samples.compactMap(\.acceleration)
        strongestAcceleration = accelerations.max().flatMap { $0 > 0 ? $0 : nil }
        strongestBraking = accelerations.min().flatMap { $0 < 0 ? -$0 : nil }
        sprint = Self.bestSprint(samples, targetKmh: Self.sprintTarget(motorized: motorized))
        roughShare = Self.roughShare(samples)
    }

    /// The share of the distance whose roughness is at least `SurfaceBand.uneven`; each step between
    /// two samples counts with the roughness of the later one, steps over a gap not at all.
    static func roughShare(_ samples: [RideSample]) -> Double? {
        var total = 0.0
        var rough = 0.0
        var previous: RideSample?
        for sample in samples.sorted(by: { $0.time < $1.time }) {
            defer { previous = sample }
            guard let p = previous, let roughness = sample.roughness, let to = sample.distance, let from = p.distance,
                  sample.time - p.time <= maxSampleGap else { continue }
            let step = max(to - from, 0)
            total += step
            if SurfaceBand(roughness: roughness) >= .uneven { rough += step }
        }
        return total > 0 ? rough / total : nil
    }

    /// The fastest time from the last moment below `standstillKmh` to reaching `targetKmh`, with the
    /// crossing interpolated between the two samples around it.
    static func bestSprint(_ samples: [RideSample], targetKmh: Double) -> Sprint? {
        var best: Double?
        var standing: Double?
        var previous: (time: Double, kmh: Double)?
        for sample in samples.sorted(by: { $0.time < $1.time }) {
            guard let speed = sample.speed, speed.isFinite, speed >= 0 else { continue }
            let kmh = speed * 3.6
            if let p = previous, sample.time - p.time > maxSampleGap { standing = nil }
            if kmh <= standstillKmh {
                standing = sample.time
            } else if let start = standing, let p = previous, p.kmh < targetKmh, kmh >= targetKmh {
                let crossing = p.time + (targetKmh - p.kmh) / (kmh - p.kmh) * (sample.time - p.time)
                let seconds = crossing - start
                if seconds > 0, seconds <= maxSprintSeconds { best = min(best ?? seconds, seconds) }
                standing = nil
            }
            previous = (sample.time, kmh)
        }
        return best.map { Sprint(targetKmh: targetKmh, seconds: $0) }
    }

    // MARK: - The track by lean angle

    /// How strongly the bike leans on a stretch, for the colour of the track on the map.
    public enum LeanBand: Int, CaseIterable, Sendable, Comparable {
        /// Below 10°.
        case upright
        /// 10° to 20°.
        case slight
        /// 20° to 30°.
        case medium
        /// 30° to 40°.
        case strong
        /// 40° and more.
        case extreme

        /// The lowest lean of the band, in degrees.
        public var lowerBound: Double { Double(rawValue) * 10 }

        public init(lean: Double) {
            self = LeanBand(rawValue: min(Int(abs(lean) / 10), LeanBand.extreme.rawValue)) ?? .upright
        }

        public static func < (a: LeanBand, b: LeanBand) -> Bool { a.rawValue < b.rawValue }
    }

    /// How rough the road was on a stretch (B-248), for the colour of the track on the map. The
    /// limits come from two e-bike test rides of V-16 with the iPhone in the handlebar mount,
    /// checked against the surface in OpenStreetMap (`docs/SPIKE-BEWEGUNG.md`).
    public enum SurfaceBand: Int, CaseIterable, Sendable, Comparable {
        /// Below 0.2 g: asphalt (0.10 to 0.17 g on the test rides).
        case smooth
        /// 0.2 g to 0.45 g: field paths, smooth gravel paths, paving stones.
        case uneven
        /// 0.45 g and more: forest tracks and off-road (0.6 to 0.8 g on the test rides).
        case rough

        /// The lowest roughness of the band, in g.
        public static let unevenFrom = 0.2
        public static let roughFrom = 0.45

        public init(roughness: Double) {
            self = roughness >= Self.roughFrom ? .rough : roughness >= Self.unevenFrom ? .uneven : .smooth
        }

        public static func < (a: SurfaceBand, b: SurfaceBand) -> Bool { a.rawValue < b.rawValue }
    }

    /// A piece of the track with one band; the next piece starts at its last point, so the line
    /// has no holes.
    public struct Stretch<Band: Sendable & Equatable>: Sendable, Equatable {
        public var band: Band
        public var latitude: [Double]
        public var longitude: [Double]
    }

    public typealias LeanStretch = Stretch<LeanBand>
    public typealias SurfaceStretch = Stretch<SurfaceBand>

    /// The track in pieces of the same lean band, broken where the samples are more than
    /// `maxSampleGap` seconds apart (pause); empty without lean angles. Samples without a lean count
    /// as upright.
    public static func leanStretches(_ samples: [RideSample]) -> [LeanStretch] {
        guard samples.contains(where: { $0.lean != nil }) else { return [] }
        return stretches(samples) { LeanBand(lean: $0.lean ?? 0) }
    }

    /// The track in pieces of the same surface band (B-248), like `leanStretches`; empty without
    /// roughness values. Samples without one count as smooth.
    public static func surfaceStretches(_ samples: [RideSample]) -> [SurfaceStretch] {
        guard samples.contains(where: { $0.roughness != nil }) else { return [] }
        return stretches(samples) { SurfaceBand(roughness: $0.roughness ?? 0) }
    }

    private static func stretches<Band>(_ samples: [RideSample], band bandOf: (RideSample) -> Band) -> [Stretch<Band>] {
        var stretches: [Stretch<Band>] = []
        var current: Stretch<Band>?
        var lastTime: Double?
        for sample in samples.sorted(by: { $0.time < $1.time }) {
            guard let latitude = sample.latitude, let longitude = sample.longitude else { continue }
            let band = bandOf(sample)
            if let last = lastTime, sample.time - last > maxSampleGap, let piece = current {
                if piece.latitude.count > 1 { stretches.append(piece) }
                current = nil
            }
            lastTime = sample.time
            if var piece = current {
                piece.latitude.append(latitude)
                piece.longitude.append(longitude)
                if piece.band != band {
                    stretches.append(piece)
                    current = Stretch(band: band, latitude: [latitude], longitude: [longitude])
                } else {
                    current = piece
                }
            } else {
                current = Stretch(band: band, latitude: [latitude], longitude: [longitude])
            }
        }
        if let piece = current, piece.latitude.count > 1 { stretches.append(piece) }
        return stretches
    }
}
