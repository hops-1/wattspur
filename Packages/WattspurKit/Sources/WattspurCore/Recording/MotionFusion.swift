import Foundation

/// What the motion sensors add to one GPS point of a recording (B-245): the lean angle, the
/// acceleration along the way and how rough the road was, each for the time since the point before.
public struct MotionValues: Codable, Sendable, Equatable {
    /// Degrees, positive leaning left, negative leaning right; the strongest lean of the interval.
    /// 0 while slower than `MotionFusion.minLeanSpeed`.
    public var lean: Double
    /// In g along the way, positive speeding up, negative braking; the strongest of the interval.
    /// `nil` without a valid GPS speed.
    public var acceleration: Double?
    /// The shaking of the road (B-248): root mean square of the vertical acceleration in g, without
    /// slow movements such as the ride over a hill.
    public var roughness: Double

    public init(lean: Double, acceleration: Double?, roughness: Double) {
        self.lean = lean
        self.acceleration = acceleration
        self.roughness = roughness
    }

    /// Both intervals as one, for a GPS point the recording dropped: the stronger lean and
    /// acceleration, the larger roughness (an estimate; the readings are gone).
    public func merged(with later: MotionValues?) -> MotionValues {
        guard let later else { return self }
        let acceleration: Double? = switch (self.acceleration, later.acceleration) {
        case let (a?, b?): abs(a) >= abs(b) ? a : b
        case let (a, b): a ?? b
        }
        return MotionValues(lean: abs(lean) >= abs(later.lean) ? lean : later.lean,
                            acceleration: acceleration, roughness: max(roughness, later.roughness))
    }
}

/// Turns the device-motion readings (50 Hz) and the GPS points into `MotionValues`, one set per GPS
/// point. Pure and step by step, so the iPhone feeds it while riding and the tests with made-up rides.
///
/// - **Lean angle:** not the tilt of the iPhone: in a turn the apparent gravity points along the
///   vehicle. It comes from the speed and the turn rate about the vertical:
///   tan(lean) = v · ω / g, with ω the rotation rate projected on “up” (the opposite of gravity).
///   That works whatever way the iPhone sits in the mount or the pocket.
/// - **Acceleration along the way:** the horizontal acceleration without the part of the turn
///   (v · ω) is what speeds up or brakes; the GPS speed says which of the two it is.
/// - **Roughness:** the vertical acceleration after the slow part is taken away.
///
/// Readings are smoothed over about half a second against the vibration of the engine; the
/// values are tuned with the test rides of spike V-16 (`docs/SPIKE-BEWEGUNG.md`).
public struct MotionFusion: Sendable {
    public typealias Reading = MotionRawLog.Motion

    public static let gravity = 9.80665
    /// Below 10 km/h the GPS speed is too unsure for a lean angle (spike V-16 at the desk: 14°
    /// from GPS noise and a turned iPhone).
    public static let minLeanSpeed = 10 / 3.6
    /// More is a misreading, not a ride.
    public static let maxLean = 70.0
    /// Seconds; the time constant of the low-pass filter against engine vibration.
    public static let smoothing: TimeInterval = 0.25
    /// In g: a smaller change of the GPS speed counts as riding steadily.
    public static let steadyAcceleration = 0.03
    /// A reading this long after the one before starts the filters afresh (pause, app in background).
    static let maxReadingGap: TimeInterval = 0.5

    // The filters.
    private var lastReading: Date?
    private var yaw = 0.0
    private var horizontal = (x: 0.0, y: 0.0, z: 0.0)
    private var vertical = 0.0

    // The interval since the last GPS point.
    private var strongestLean = 0.0
    private var strongestAlong = 0.0
    private var squares = 0.0
    private var count = 0

    // The GPS.
    private var speed: Double?
    private var lastFix: (date: Date, speed: Double)?

    public init() {}

    /// One device-motion reading.
    public mutating func add(_ reading: Reading) {
        let g = reading.gravity
        let norm = (g.x * g.x + g.y * g.y + g.z * g.z).squareRoot()
        guard norm > 0.5, norm.isFinite else { return }
        let up = (x: -g.x / norm, y: -g.y / norm, z: -g.z / norm)
        let r = reading.rotation
        let a = reading.acceleration
        let turn = r.x * up.x + r.y * up.y + r.z * up.z
        let lift = a.x * up.x + a.y * up.y + a.z * up.z
        let flat = (x: a.x - lift * up.x, y: a.y - lift * up.y, z: a.z - lift * up.z)
        guard turn.isFinite, lift.isFinite else { return }

        let gap = lastReading.map { reading.date.timeIntervalSince($0) } ?? .infinity
        lastReading = reading.date
        if gap <= 0 { return }
        if gap > Self.maxReadingGap {
            yaw = turn
            horizontal = flat
            vertical = lift
            return
        }
        let k = gap / (Self.smoothing + gap)
        yaw += k * (turn - yaw)
        horizontal.x += k * (flat.x - horizontal.x)
        horizontal.y += k * (flat.y - horizontal.y)
        horizontal.z += k * (flat.z - horizontal.z)
        vertical += k * (lift - vertical)

        // Roughness: what is left of the vertical acceleration after its slow part.
        let shake = lift - vertical
        squares += shake * shake
        count += 1

        guard let v = speed else { return }
        let sideways = v * yaw / Self.gravity // in g
        if v >= Self.minLeanSpeed {
            let lean = min(max(atan(sideways) * 180 / .pi, -Self.maxLean), Self.maxLean)
            if abs(lean) > abs(strongestLean) { strongestLean = lean }
        }
        let flatSquared = horizontal.x * horizontal.x + horizontal.y * horizontal.y + horizontal.z * horizontal.z
        let along = max(flatSquared - sideways * sideways, 0).squareRoot()
        strongestAlong = max(strongestAlong, along)
    }

    /// Closes the interval at a GPS point and starts the next. `speed` in m/s, `nil` or negative if
    /// unknown. Returns `nil` if no reading came since the last point (no sensors, or a gap).
    public mutating func close(at date: Date, speed newSpeed: Double?) -> MotionValues? {
        let valid = newSpeed.flatMap { $0 >= 0 && $0.isFinite ? $0 : nil }
        defer {
            strongestLean = 0
            strongestAlong = 0
            squares = 0
            count = 0
            speed = valid
            lastFix = valid.map { (date, $0) }
        }
        guard count > 0 else { return nil }

        var acceleration: Double?
        if let valid, let lastFix, date > lastFix.date {
            // The GPS says whether it was speeding up or braking, the sensors how strongly.
            let change = (valid - lastFix.speed) / date.timeIntervalSince(lastFix.date) / Self.gravity
            if abs(change) < Self.steadyAcceleration {
                acceleration = change
            } else {
                acceleration = (change > 0 ? 1 : -1) * max(strongestAlong, abs(change))
            }
        }
        return MotionValues(lean: strongestLean, acceleration: acceleration,
                            roughness: (squares / Double(count)).squareRoot())
    }
}
