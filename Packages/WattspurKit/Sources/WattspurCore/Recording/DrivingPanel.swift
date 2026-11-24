import Foundation

/// The figures CarPlay shows while recording (B-327): speed, time, distance and, in a car, the
/// lateral acceleration, on a motorcycle the lean angle. Only numbers; the app writes the texts.
///
/// Apple describes a Driving Task app as one without frequent updates (V-20), so the panel is
/// written anew at most every `refreshInterval` seconds; a change of the state (start, pause, end)
/// shows at once.
public struct DrivingPanel: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Nothing is recorded.
        case idle
        /// Auto-start waits for the vehicle to move (B-311).
        case ready
        case recording
        case paused
        /// A ride the app could not finish waits for the rider (B-383): CarPlay offers to continue
        /// it, never a new start, which would throw it away.
        case unfinished
    }

    public static let refreshInterval: TimeInterval = 5

    public var state: State
    /// Metres per second; 0 while paused or ready.
    public var speed: Double
    /// Seconds since the start, as on the iPhone's recording screen.
    public var elapsed: TimeInterval
    /// Metres.
    public var distance: Double
    /// Lateral acceleration for a car, lean angle otherwise; `nil` for devices without one.
    public var sideMeasure: SideMeasure?
    /// The stored lean angle of the last position in degrees (`SideMeasure.text(lean:)` turns it
    /// into “0.39 g” or “38°”); `nil` while paused, ready or without motion sensors.
    public var lean: Double?

    public init(state: State, speed: Double = 0, elapsed: TimeInterval = 0, distance: Double = 0,
                sideMeasure: SideMeasure? = nil, lean: Double? = nil) {
        self.state = state
        self.speed = speed
        self.elapsed = elapsed
        self.distance = distance
        self.sideMeasure = sideMeasure
        self.lean = lean
    }

    /// The panel for `recording` at `date`; `nil` gives the idle panel, or with `unfinished` the
    /// ride that waits to be continued, with its distance.
    public init(recording: RideRecording?, unfinished: RideRecording? = nil, at date: Date) {
        guard let recording else {
            if let unfinished {
                self.init(state: .unfinished, distance: unfinished.distance)
            } else {
                self.init(state: .idle)
            }
            return
        }
        let state: State = recording.isReady ? .ready : recording.isPaused ? .paused : .recording
        let kind = recording.device?.kind
        let measure: SideMeasure? = switch kind {
        case .car: .lateralAcceleration
        case .motorcycle: .leanAngle
        default: nil
        }
        self.init(state: state,
                  speed: state == .recording ? recording.currentSpeed : 0,
                  elapsed: state == .ready ? 0 : max(0, date.timeIntervalSince(recording.startDate)),
                  distance: recording.distance,
                  sideMeasure: measure,
                  lean: state == .recording && measure != nil ? recording.lastPoint?.fix.motion?.lean : nil)
    }

    /// Whether the panel shown since `shownAt` should be written anew with this one at `date`:
    /// at once when the state changed, else once `refreshInterval` has passed and a figure changed.
    public func needsRefresh(since shown: DrivingPanel?, shownAt: Date?, at date: Date) -> Bool {
        guard let shown, let shownAt else { return true }
        if shown.state != state || shown.sideMeasure != sideMeasure { return true }
        guard date.timeIntervalSince(shownAt) >= Self.refreshInterval else { return false }
        return shown != self
    }

    /// The vehicles CarPlay offers (B-327): the open devices of the sport “Vehicles” in their order,
    /// then a car and a motorcycle without a device.
    public static func vehicles(from devices: [RideExchange.Bike]) -> [RecordingDevice] {
        let own = devices.compactMap { device -> RecordingDevice? in
            guard !device.isArchived, let kind = BikeKind(rawValue: device.kind), kind.sport == .vehicle else { return nil }
            return RecordingDevice(bikeID: device.id, kind: kind)
        }
        return own + [.without(.car), .without(.motorcycle)]
    }
}
