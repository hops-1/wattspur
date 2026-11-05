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

    /// A piece of the track with one band; the next piece starts at its last point, so the line
    /// has no holes.
    public struct LeanStretch: Sendable, Equatable {
        public var band: LeanBand
        public var latitude: [Double]
        public var longitude: [Double]
    }

    /// The track in pieces of the same lean band, broken where the samples are more than
    /// `maxSampleGap` seconds apart (pause); empty without lean angles. Samples without a lean count
    /// as upright.
    public static func leanStretches(_ samples: [RideSample]) -> [LeanStretch] {
        guard samples.contains(where: { $0.lean != nil }) else { return [] }
        var stretches: [LeanStretch] = []
        var current: LeanStretch?
        var lastTime: Double?
        for sample in samples.sorted(by: { $0.time < $1.time }) {
            guard let latitude = sample.latitude, let longitude = sample.longitude else { continue }
            let band = LeanBand(lean: sample.lean ?? 0)
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
                    current = LeanStretch(band: band, latitude: [latitude], longitude: [longitude])
                } else {
                    current = piece
                }
            } else {
                current = LeanStretch(band: band, latitude: [latitude], longitude: [longitude])
            }
        }
        if let piece = current, piece.latitude.count > 1 { stretches.append(piece) }
        return stretches
    }
}
