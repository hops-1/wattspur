import Foundation

/// A ride recorded with the iPhone's GPS (B-211). Collects the positions, drops the bad ones and
/// keeps the figures shown while riding: time, distance, speed and altitude. Pause starts a new
/// segment, so the GPX keeps the gap instead of drawing a line across it.
///
/// The rules (V-14, spike notes in docs/SPIKE-IOS.md):
/// - A position less accurate than `maxAccuracy` is dropped (tunnels, start of the recording).
/// - Until the first position is kept, it has to be as accurate as `startAccuracy`: in the first
///   seconds the GPS jumps by tens of metres while it settles (54 m at a standstill in a test on
///   5.11.2026). After `startTimeout` the normal limit is enough, so a recording still begins.
/// - A position that would mean more than the vehicle's top speed since the last one is a jump and
///   is dropped: `maxSpeed` for an e-bike, more for a motorcycle (`RecordingVehicle`).
/// - A position more than `TrackGap.distance` away after more than `maxGap` without one starts a
///   new segment, like a pause: the train ride between two stations adds no distance (B-309).
/// - Distance only grows once the position is `minStep` away from where it last grew, so the GPS
///   wandering around a standing bike adds nothing.
/// - Moving time counts the time between two such steps when it was faster than `minMovingSpeed`
///   and shorter than `maxGap`: standing at a traffic light is a pause, like on the Mac.
public struct RideRecording: Codable, Sendable, Equatable {
    /// One position as the location service delivers it.
    public struct Fix: Codable, Sendable, Equatable {
        public var date: Date
        public var latitude: Double
        public var longitude: Double
        /// Metres above sea level; `nil` without a valid vertical position.
        public var altitude: Double?
        /// Radius of uncertainty in metres; negative means invalid.
        public var horizontalAccuracy: Double
        /// Metres per second as measured by the device; `nil` if unknown.
        public var speed: Double?
        /// Lean angle, acceleration and roughness since the position before (B-245); `nil` without
        /// motion sensors and in logs from before 0.5.1.
        public var motion: MotionValues?

        public init(date: Date, latitude: Double, longitude: Double, altitude: Double? = nil,
                    horizontalAccuracy: Double, speed: Double? = nil, motion: MotionValues? = nil) {
            self.date = date
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
            self.horizontalAccuracy = horizontalAccuracy
            self.speed = speed
            self.motion = motion
        }
    }

    /// A kept position with the distance ridden up to it.
    public struct Point: Codable, Sendable, Equatable {
        public var fix: Fix
        /// Metres since the start of the recording.
        public var distance: Double
    }

    public static let maxAccuracy = 30.0
    /// Metres; the first position of a recording has to be this accurate.
    public static let startAccuracy = 10.0
    /// Seconds after the start when the first position only has to meet `maxAccuracy`.
    public static let startTimeout: TimeInterval = 30
    /// 100 km/h: faster than any e-bike, slower than a GPS jump.
    public static let maxSpeed = 100 / 3.6
    public static let minStep = 5.0
    /// 2 km/h.
    public static let minMovingSpeed = 2 / 3.6
    public static let maxGap: TimeInterval = 30

    public var startDate: Date
    /// Stored as optional, so recordings from before the choice still decode.
    private var storedVehicle: RecordingVehicle?
    /// What is recorded; it sets the speed above which a step counts as a GPS jump.
    public var vehicle: RecordingVehicle {
        get { storedVehicle ?? .eBike }
        set { storedVehicle = newValue }
    }
    /// What it is recorded with (B-286): a device, or a car or motorcycle without one; `nil` in
    /// recordings from before the choice, which save with the bike picked then.
    public var device: RecordingDevice? {
        didSet { if let device { storedVehicle = device.vehicle } }
    }
    /// One segment per stretch between start or resume and pause or stop.
    public private(set) var segments: [[Point]] = [[]]
    public private(set) var isPaused = false
    /// Metres.
    public private(set) var distance: Double = 0
    /// Seconds in motion.
    public private(set) var movingTime: TimeInterval = 0
    /// Where the distance last grew.
    private var anchor: Fix?
    /// Stored as optional, so recordings from before auto-start (B-311) still decode.
    private var storedReady: Bool?
    /// Waiting for the vehicle to move (auto-start, B-311): positions are not kept until one is
    /// faster than `AutoStart.startSpeed`; that one begins the ride and its time becomes the start.
    public var isReady: Bool { storedReady == true }

    public init(startDate: Date, vehicle: RecordingVehicle = .eBike) {
        self.startDate = startDate
        self.storedVehicle = vehicle
    }

    /// A recording with a device (B-286); the device sets the vehicle, and with it the speed limit.
    public init(startDate: Date, device: RecordingDevice) {
        self.startDate = startDate
        self.storedVehicle = device.vehicle
        self.device = device
    }

    /// Lets the recording wait until the vehicle moves (B-311); only before the first position.
    public mutating func waitForMovement() {
        guard isWaitingForGPS else { return }
        storedReady = true
    }

    /// Adds a position; returns `false` if it was dropped (or the recording is paused or ready).
    @discardableResult
    public mutating func add(_ fix: Fix) -> Bool {
        guard !isPaused, fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= Self.maxAccuracy else { return false }
        // Ready: the first fast position begins the ride. The GPS has settled while waiting, so it
        // does not have to meet `startAccuracy`.
        var begins = false
        if isReady {
            // A position from before the start is one iOS kept from earlier, maybe with the speed of
            // the last drive (seen in the simulator); it says nothing about moving now.
            guard fix.date >= startDate, AutoStart.begins(with: fix) else { return false }
            storedReady = nil
            startDate = fix.date
            begins = true
        }
        if !begins, isWaitingForGPS, fix.horizontalAccuracy > Self.startAccuracy,
           fix.date.timeIntervalSince(startDate) < Self.startTimeout {
            return false
        }
        let index = segments.count - 1
        guard let last = segments[index].last else {
            segments[index].append(Point(fix: fix, distance: distance))
            anchor = fix
            return true
        }
        let seconds = fix.date.timeIntervalSince(last.fix.date)
        guard seconds > 0 else { return false }
        let step = GPXGeo.distance(last.fix.latitude, last.fix.longitude, fix.latitude, fix.longitude)
        // Far away after a while without positions, e.g. off the train (B-309): a new stretch, as
        // after a pause, so the distance does not jump and later positions are no GPS jumps.
        if seconds > Self.maxGap, step > TrackGap.distance {
            startStretch()
            segments[segments.count - 1].append(Point(fix: fix, distance: distance))
            anchor = fix
            return true
        }
        guard step / seconds <= vehicle.maxSpeed else { return false }

        if let anchor {
            let fromAnchor = GPXGeo.distance(anchor.latitude, anchor.longitude, fix.latitude, fix.longitude)
            // A little slack, so steps of exactly 5 m are not lost to rounding.
            if fromAnchor >= Self.minStep * 0.99 {
                distance += fromAnchor
                // The time since the distance last grew counts as riding, unless it was too slow
                // or too long: then the bike stood (or the GPS was gone) and it is a pause.
                let since = fix.date.timeIntervalSince(anchor.date)
                if since <= Self.maxGap, fromAnchor / since >= Self.minMovingSpeed {
                    movingTime += since
                }
                self.anchor = fix
            }
        }
        segments[index].append(Point(fix: fix, distance: distance))
        return true
    }

    public mutating func pause() {
        isPaused = true
    }

    /// Continues in a new segment; the distance does not jump over the gap.
    public mutating func resume() {
        guard isPaused else { return }
        isPaused = false
        startStretch()
    }

    /// Ends the current stretch (if it has positions) and starts an empty one.
    private mutating func startStretch() {
        if !(segments.last ?? []).isEmpty { segments.append([]) }
        anchor = nil
        // Everything but the new, empty stretch is finished now.
        let finished = segments.count - 1
        let cache = ascentCache ?? AscentCache()
        if finished > cache.segments {
            let more = Self.climb(of: segments[cache.segments..<finished])
            ascentCache = AscentCache(segments: finished, metres: cache.metres + more.metres,
                                      hasHeights: cache.hasHeights || more.hasHeights)
        }
    }

    // MARK: - Figures while riding

    public var lastPoint: Point? { segments.last(where: { !$0.isEmpty })?.last }

    /// Metres per second over the last few seconds; 0 while standing or paused.
    public var currentSpeed: Double {
        guard !isPaused, let points = segments.last, let last = points.last else { return 0 }
        if let speed = last.fix.speed, speed >= 0 { return speed }
        guard let earlier = points.last(where: { last.fix.date.timeIntervalSince($0.fix.date) >= 5 }) else { return 0 }
        let metres = GPXGeo.distance(earlier.fix.latitude, earlier.fix.longitude, last.fix.latitude, last.fix.longitude)
        return metres / last.fix.date.timeIntervalSince(earlier.fix.date)
    }

    /// Metres per second over the time in motion; 0 before the first metres.
    public var averageSpeed: Double {
        movingTime > 0 ? distance / movingTime : 0
    }

    /// Whole metres of climbing so far, counted like the ascent of a GPX ride (smoothed heights,
    /// `GPXSummaryParameters.ascentThreshold`), so the figure while riding matches the saved ride;
    /// `nil` while no stretch has two heights. Shown in the landscape recording (B-243).
    public var ascent: Int? {
        // Finished stretches come from the cache; only the current one is counted again (R-26).
        let done = ascentCache.flatMap { $0.segments < segments.count ? $0 : nil } ?? AscentCache()
        let rest = Self.climb(of: segments[done.segments...])
        let hasHeights = done.hasHeights || rest.hasHeights
        return hasHeights ? Int((done.metres + rest.metres).rounded()) : nil
    }

    /// The climb of the stretches before the current one, so `ascent` need not count them again.
    struct AscentCache: Codable, Sendable, Equatable {
        var segments = 0
        var metres = 0.0
        var hasHeights = false
    }

    private var ascentCache: AscentCache?

    private static func climb(of stretches: ArraySlice<[Point]>) -> (metres: Double, hasHeights: Bool) {
        let parameters = GPXSummaryParameters.standard
        var total = 0.0
        var hasHeights = false
        for points in stretches {
            let heights = points.compactMap(\.fix.altitude)
            guard heights.count >= 2 else { continue }
            hasHeights = true
            total += GPXTrack.climb(GPXTrack.median(heights, points: parameters.altitudeMedianPoints),
                                    threshold: parameters.ascentThreshold).up
        }
        return (total, hasHeights)
    }

    public var pointCount: Int { segments.reduce(0) { $0 + $1.count } }

    /// `true` until the first position is kept: the GPS is still settling (shown while recording).
    public var isWaitingForGPS: Bool { pointCount == 0 }

    /// `true` while no stretch has two positions at least a second apart: GPX counts whole seconds,
    /// so such a recording is no track, and the Mac would put it into “Failed”.
    public var isTooShort: Bool {
        !segments.contains { points in
            guard let first = points.first, let last = points.last else { return false }
            return last.fix.date.timeIntervalSince(first.fix.date) >= 1
        }
    }

    // MARK: - Output

    /// The recording as samples for the GPX writer: one segment per stretch, times from its start.
    public var gpxSegments: [GPXWriter.Segment] {
        segments.filter { !$0.isEmpty }.map { points in
            let start = points[0].fix.date
            return GPXWriter.Segment(startDate: start, samples: points.map { point in
                RideSample(time: point.fix.date.timeIntervalSince(start),
                           latitude: point.fix.latitude, longitude: point.fix.longitude,
                           altitude: point.fix.altitude, distance: point.distance, speed: point.fix.speed,
                           horizontalAccuracy: point.fix.horizontalAccuracy,
                           lean: point.fix.motion?.lean,
                           acceleration: point.fix.motion?.acceleration,
                           roughness: point.fix.motion?.roughness)
            })
        }
    }

    /// The track for the map while riding: a point every 10 m is plenty and keeps a long ride light.
    public var route: RideExchange.Route {
        RideExchange.Route(rideID: UUID(), segments: segments.map { points in
            var kept: [Point] = []
            for (index, point) in points.enumerated() {
                if index == points.count - 1 || (kept.last.map { point.distance - $0.distance >= 10 } ?? true) {
                    kept.append(point)
                }
            }
            return RideExchange.Route.Segment(latitude: kept.map(\.fix.latitude), longitude: kept.map(\.fix.longitude),
                                              altitude: kept.map(\.fix.altitude), distance: kept.map(\.distance))
        })
    }
}

/// The recording as it happens, one JSON line per event, so a crash or a killed app loses at most
/// the line being written (B-211). Replaying the lines gives the recording back.
/// What the iPhone records. GPS jumps look like impossible speeds; what is impossible depends on
/// the vehicle. Faster than 300 km/h is a jump on a motorcycle too.
public enum RecordingVehicle: String, Codable, CaseIterable, Identifiable, Sendable {
    case eBike = "ebike"
    case motorcycle
    /// A car (B-287): fast like a motorcycle; the recording shows the lateral acceleration.
    case car

    public var id: Self { self }

    /// Metres per second.
    public var maxSpeed: Double {
        switch self {
        case .eBike: RideRecording.maxSpeed
        case .motorcycle, .car: 300 / 3.6
        }
    }

    /// What the recording shows beside the speed (B-287): the lean angle, or a car's lateral acceleration.
    public var side: SideMeasure { self == .car ? .lateralAcceleration : .leanAngle }
}

public enum RecordingLog {
    public enum Event: Codable, Sendable, Equatable {
        case start(Date)
        /// Written right after the start; logs from before it mean an e-bike.
        case vehicle(RecordingVehicle)
        /// Written right after the start from B-286 on: what it is recorded with.
        case device(RecordingDevice)
        case fix(RideRecording.Fix)
        case pause
        case resume
        /// Written right after the start of an auto-start (B-311): the recording waits for movement.
        case ready
    }

    public static func line(_ event: Event) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        var data = (try? encoder.encode(event)) ?? Data()
        data.append(0x0A)
        return data
    }

    /// The recording from a log; `nil` without a start. A line that cannot be read (the last one,
    /// cut off by a crash) is skipped.
    public static func replay(_ data: Data) -> RideRecording? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        var recording: RideRecording?
        for line in data.split(separator: 0x0A) {
            guard let event = try? decoder.decode(Event.self, from: Data(line)) else { continue }
            switch event {
            case .start(let date): recording = RideRecording(startDate: date)
            case .vehicle(let vehicle): recording?.vehicle = vehicle
            case .device(let device): recording?.device = device
            case .fix(let fix): recording?.add(fix)
            case .pause: recording?.pause()
            case .resume: recording?.resume()
            case .ready: recording?.waitForMovement()
            }
        }
        return recording
    }
}

/// What a recording is made with (B-286): one of the devices, or a car or motorcycle without one
/// (the quick start). The kind is kept with it, so the recording knows its speed limit and what to
/// show without the library.
public struct RecordingDevice: Codable, Hashable, Sendable {
    /// The device; `nil` for a recording without one.
    public var bikeID: UUID?
    /// `BikeKind` raw value: the device's kind, or the kind without a device.
    public var kindRawValue: String

    public init(bikeID: UUID?, kind: BikeKind) {
        self.bikeID = bikeID
        kindRawValue = kind.rawValue
    }

    /// A car or motorcycle without a device.
    public static func without(_ kind: BikeKind) -> RecordingDevice { RecordingDevice(bikeID: nil, kind: kind) }

    /// The kinds offered without a device (B-321): a hired bicycle, a car or a motorcycle.
    public static let vehicleTypes: [BikeKind] = [.bike, .car, .motorcycle]

    public var kind: BikeKind { BikeKind(rawValue: kindRawValue) ?? .bike }

    /// The speed limit for GPS jumps and what the recording shows beside the speed.
    public var vehicle: RecordingVehicle {
        switch kind {
        case .car: .car
        case .motorcycle: .motorcycle
        case .bike, .mountain, .road, .gravel, .cargo, .scooter, .runningShoe: .eBike
        }
    }

    /// The device for the next recording: the last one if it is still there and not archived (or
    /// the last kind without a device), else the active bike, else the first open device, else a
    /// bicycle without one. `oldVehicle` is the setting in “More” before B-286: a motorcycle or car
    /// there starts without a device of that kind, until the first choice.
    public static func next(last: RecordingDevice?, devices: [RideExchange.Bike], activeID: UUID?,
                            oldVehicle: RecordingVehicle? = nil) -> RecordingDevice {
        let open = devices.filter { !$0.isArchived }
        func device(_ id: UUID?) -> RecordingDevice? {
            guard let id, let bike = open.first(where: { $0.id == id }) else { return nil }
            return RecordingDevice(bikeID: bike.id, kind: BikeKind(rawValue: bike.kind) ?? .bike)
        }
        if let last {
            if last.bikeID == nil { return last }
            if let still = device(last.bikeID) { return still }
        } else if let oldVehicle, oldVehicle != .eBike {
            return .without(oldVehicle == .car ? .car : .motorcycle)
        }
        return device(activeID) ?? device(open.first?.id) ?? .without(.bike)
    }

    /// The device for the next recording in the sport of the capsule (B-324): with “Cycling” shown, a
    /// bike, with “Vehicles” a vehicle. The general choice while it is of that sport; else the last
    /// device chosen in that sport, the device of its last ride, the active bike, its first open
    /// device, and last a bicycle or car without a device.
    public static func next(for sport: Sport, last: RecordingDevice?, lastOfSport: RecordingDevice?,
                            lastRideDeviceID: UUID?, devices: [RideExchange.Bike], activeID: UUID?,
                            oldVehicle: RecordingVehicle? = nil) -> RecordingDevice {
        let general = next(last: last, devices: devices, activeID: activeID, oldVehicle: oldVehicle)
        if general.kind.sport == sport { return general }
        let open = devices.filter { !$0.isArchived && (BikeKind(rawValue: $0.kind) ?? .bike).sport == sport }
        func device(_ id: UUID?) -> RecordingDevice? {
            guard let id, let bike = open.first(where: { $0.id == id }) else { return nil }
            return RecordingDevice(bikeID: bike.id, kind: BikeKind(rawValue: bike.kind) ?? .bike)
        }
        if let lastOfSport, lastOfSport.kind.sport == sport {
            if lastOfSport.bikeID == nil { return lastOfSport }
            if let still = device(lastOfSport.bikeID) { return still }
        }
        if let found = device(lastRideDeviceID) ?? device(activeID) ?? device(open.first?.id) { return found }
        switch sport {
        case .cycling: return .without(.bike)
        case .vehicle: return .without(.car)
        case .running: return general
        }
    }
}
