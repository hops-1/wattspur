import Foundation

/// Auto-start, stage 1 (B-311): a Shortcuts automation runs “Start Ride” when the iPhone connects to
/// CarPlay or a Bluetooth device (a car's hands-free, a motorcycle headset). The recording then
/// waits as “Ready” and the track begins once the vehicle moves. iOS does not let an app bring
/// itself to the front, so the automation is the trigger; this is only the logic behind it.
public enum AutoStart {
    /// 10 km/h: from here on the vehicle moves; walking to the car or the GPS wandering at a
    /// standstill stays below.
    public static let startSpeed = 10 / 3.6

    /// Whether this position begins the ride of a recording that is ready: fast enough, measured by
    /// the device (not from two jumpy positions), and accurate enough to be kept.
    public static func begins(with fix: RideRecording.Fix) -> Bool {
        guard let speed = fix.speed, speed >= startSpeed else { return false }
        return fix.horizontalAccuracy >= 0 && fix.horizontalAccuracy <= RideRecording.maxAccuracy
    }

    /// The device whose connection is there now: CarPlay first (it is the car itself), then a
    /// Bluetooth device by its name. Only open devices count; `nil` when none matches, and the
    /// recording takes the last device then.
    public static func device(for ports: [AudioPort], triggers: [UUID: Trigger],
                              devices: [RideExchange.Bike]) -> RecordingDevice? {
        let open = devices.filter { !$0.isArchived }
        func first(_ matches: (Trigger) -> Bool) -> RecordingDevice? {
            for bike in open {
                if let trigger = triggers[bike.id], matches(trigger) {
                    return RecordingDevice(bikeID: bike.id, kind: BikeKind(rawValue: bike.kind) ?? .bike)
                }
            }
            return nil
        }
        if ports.contains(where: { $0.kind == .carPlay }), let device = first({ $0 == .carPlay }) {
            return device
        }
        let names = ports.filter { $0.kind == .bluetooth }.map { $0.name }
        return first { trigger in
            guard case .bluetooth(let name) = trigger else { return false }
            return names.contains { $0.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        }
    }

    // MARK: - End and save (B-339)

    /// The choices for the time standing still before an auto-started ride ends, in minutes.
    public static let standstillChoices = [5, 10, 20]
    public static let defaultStandstillMinutes = 10
    /// 5 km/h: faster counts as moving for the end; the GPS wandering around a parked car stays below.
    public static let movingSpeed = 5 / 3.6
    /// An auto-started ride shorter than this is thrown away: moving the car in the drive, a test.
    public static let minDistance = 500.0

    /// Whether an auto-ended recording is worth saving.
    public static func keeps(_ recording: RideRecording) -> Bool {
        !recording.isReady && recording.distance >= minDistance && !recording.isTooShort
    }

    /// Watches for the vehicle standing still (B-339): the time since the last position faster than
    /// `movingSpeed`. “Ready” counts from its start, so it also ends when nobody drives off.
    public struct Standstill: Sendable, Equatable {
        public var limit: TimeInterval
        public private(set) var lastMove: Date

        public init(limit: TimeInterval, since start: Date) {
            self.limit = limit
            lastMove = start
        }

        public mutating func record(_ fix: RideRecording.Fix) {
            guard let speed = fix.speed, speed >= AutoStart.movingSpeed,
                  fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= RideRecording.maxAccuracy,
                  fix.date > lastMove else { return }
            lastMove = fix.date
        }

        public func isOver(at now: Date) -> Bool { now.timeIntervalSince(lastMove) >= limit }
    }

    /// What a device starts with (“Starts with: CarPlay / Bluetooth ‹name›”); kept on each iPhone,
    /// not synced, because the connection belongs to this iPhone.
    public enum Trigger: Codable, Hashable, Sendable {
        case carPlay
        case bluetooth(String)
    }

    /// An output of the current audio route, as the app reads it from `AVAudioSession`.
    public struct AudioPort: Hashable, Sendable {
        public enum Kind: Hashable, Sendable { case carPlay, bluetooth, other }
        public var kind: Kind
        public var name: String

        public init(kind: Kind, name: String) {
            self.kind = kind
            self.name = name
        }
    }
}
