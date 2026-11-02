import Foundation

/// A ride recorded with the iPhone's GPS (B-211). Collects the positions, drops the bad ones and
/// keeps the figures shown while riding: time, distance, speed and altitude. Pause starts a new
/// segment, so the GPX keeps the gap instead of drawing a line across it.
///
/// The rules (V-14, spike notes in docs/SPIKE-IOS.md):
/// - A position less accurate than `maxAccuracy` is dropped (tunnels, start of the recording).
/// - A position that would mean more than `maxSpeed` since the last one is a jump and is dropped.
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

        public init(date: Date, latitude: Double, longitude: Double, altitude: Double? = nil,
                    horizontalAccuracy: Double, speed: Double? = nil) {
            self.date = date
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
            self.horizontalAccuracy = horizontalAccuracy
            self.speed = speed
        }
    }

    /// A kept position with the distance ridden up to it.
    public struct Point: Codable, Sendable, Equatable {
        public var fix: Fix
        /// Metres since the start of the recording.
        public var distance: Double
    }

    public static let maxAccuracy = 30.0
    /// 100 km/h: faster than any e-bike, slower than a GPS jump.
    public static let maxSpeed = 100 / 3.6
    public static let minStep = 5.0
    /// 2 km/h.
    public static let minMovingSpeed = 2 / 3.6
    public static let maxGap: TimeInterval = 30

    public var startDate: Date
    /// One segment per stretch between start or resume and pause or stop.
    public private(set) var segments: [[Point]] = [[]]
    public private(set) var isPaused = false
    /// Metres.
    public private(set) var distance: Double = 0
    /// Seconds in motion.
    public private(set) var movingTime: TimeInterval = 0
    /// Where the distance last grew.
    private var anchor: Fix?

    public init(startDate: Date) {
        self.startDate = startDate
    }

    /// Adds a position; returns `false` if it was dropped (or the recording is paused).
    @discardableResult
    public mutating func add(_ fix: Fix) -> Bool {
        guard !isPaused, fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= Self.maxAccuracy else { return false }
        let index = segments.count - 1
        guard let last = segments[index].last else {
            segments[index].append(Point(fix: fix, distance: distance))
            anchor = fix
            return true
        }
        let seconds = fix.date.timeIntervalSince(last.fix.date)
        guard seconds > 0 else { return false }
        let step = GPXGeo.distance(last.fix.latitude, last.fix.longitude, fix.latitude, fix.longitude)
        guard step / seconds <= Self.maxSpeed else { return false }

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
        if !(segments.last ?? []).isEmpty { segments.append([]) }
        anchor = nil
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

    public var pointCount: Int { segments.reduce(0) { $0 + $1.count } }

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
                           altitude: point.fix.altitude, distance: point.distance, speed: point.fix.speed)
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
public enum RecordingLog {
    public enum Event: Codable, Sendable, Equatable {
        case start(Date)
        case fix(RideRecording.Fix)
        case pause
        case resume
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
            case .fix(let fix): recording?.add(fix)
            case .pause: recording?.pause()
            case .resume: recording?.resume()
            }
        }
        return recording
    }
}
